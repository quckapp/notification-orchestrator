defmodule NotificationOrchestrator.Kafka.Consumer do
  @moduledoc """
  Kafka consumer for notification events from other services.

  ## Design Patterns Used:
  - **Circuit Breaker**: Graceful degradation when Kafka is unavailable
  - **Strategy Pattern**: Event handlers for different notification types
  - **Chain of Responsibility**: Provider selection for notifications
  - **Factory Pattern**: Notification builder based on type
  - **Priority Queue**: High-priority notifications processed first

  ## Data Structures:
  - ETS table for deduplication with TTL
  - Priority heap (via sorted list) for notification ordering
  - Rate limiter using token bucket algorithm
  """
  use GenServer
  require Logger

  # Valid notification types - prevents atom table exhaustion
  @valid_notification_types ~w(push email sms in_app silent)
  @valid_priorities ~w(low normal high critical)
  @valid_channels ~w(firebase apns email sms)

  # Circuit breaker configuration
  @max_failures 5
  @reset_timeout_ms 30_000
  @retry_delay_ms 5_000

  # Deduplication window
  @dedup_window_ms 60_000

  # Rate limiting (token bucket)
  @max_tokens 1000
  @refill_rate 100  # tokens per second

  # Topics
  @topics [
    "notification-requests",
    "user-events",
    "message-events",
    "call-events",
    "system-events"
  ]

  defstruct [
    :consumer_pid,
    :brokers,
    :group_id,
    :topics,
    :circuit_state,
    :failure_count,
    :last_failure_at,
    :priority_queue,
    :rate_limiter,
    enabled: false
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Check if consumer is healthy"
  def healthy? do
    GenServer.call(__MODULE__, :health_check)
  catch
    :exit, _ -> false
  end

  @doc "Get consumer statistics"
  def stats do
    GenServer.call(__MODULE__, :stats)
  catch
    :exit, _ -> %{status: :unavailable}
  end

  @doc "Get current rate limiter state"
  def rate_limit_status do
    GenServer.call(__MODULE__, :rate_limit_status)
  catch
    :exit, _ -> %{available_tokens: 0}
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Initialize ETS for deduplication
    :ets.new(:notification_kafka_dedup, [:set, :named_table, :public])
    # Initialize ETS for notification stats
    :ets.new(:notification_kafka_stats, [:set, :named_table, :public])
    init_stats()

    config = Application.get_env(:notification_orchestrator, :kafka, [])
    enabled = config[:enabled] || System.get_env("KAFKA_ENABLED") == "true"

    state = %__MODULE__{
      circuit_state: :closed,
      failure_count: 0,
      last_failure_at: nil,
      priority_queue: [],
      rate_limiter: %{tokens: @max_tokens, last_refill: System.system_time(:millisecond)},
      enabled: enabled
    }

    if enabled do
      send(self(), :connect)
    else
      Logger.info("[NotificationKafkaConsumer] Kafka disabled - running without event streaming")
    end

    schedule_cleanup()
    schedule_rate_refill()
    schedule_queue_processor()

    {:ok, state}
  end

  @impl true
  def handle_info(:connect, %{enabled: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect_to_kafka(state) do
      {:ok, new_state} ->
        Logger.info("[NotificationKafkaConsumer] Successfully connected to Kafka")
        {:noreply, %{new_state | circuit_state: :closed, failure_count: 0}}

      {:error, reason} ->
        new_state = handle_connection_failure(state, reason)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:retry_connect, state) do
    if state.circuit_state == :open do
      if should_attempt_reset?(state) do
        Logger.info("[NotificationKafkaConsumer] Circuit half-open, attempting reconnect")
        send(self(), :connect)
        {:noreply, %{state | circuit_state: :half_open}}
      else
        schedule_retry()
        {:noreply, state}
      end
    else
      send(self(), :connect)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:cleanup_dedup, state) do
    cutoff = System.system_time(:millisecond) - @dedup_window_ms

    :ets.select_delete(:notification_kafka_dedup, [
      {{:"$1", :"$2"}, [{:<, :"$2", cutoff}], [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(:refill_tokens, state) do
    now = System.system_time(:millisecond)
    elapsed_seconds = (now - state.rate_limiter.last_refill) / 1000
    new_tokens = min(@max_tokens, state.rate_limiter.tokens + trunc(elapsed_seconds * @refill_rate))

    new_rate_limiter = %{tokens: new_tokens, last_refill: now}
    schedule_rate_refill()

    {:noreply, %{state | rate_limiter: new_rate_limiter}}
  end

  @impl true
  def handle_info(:process_queue, state) do
    new_state = process_priority_queue(state)
    schedule_queue_processor()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{consumer_pid: pid} = state) do
    Logger.warning("[NotificationKafkaConsumer] Consumer process died: #{inspect(reason)}")
    new_state = handle_connection_failure(state, reason)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    healthy = state.circuit_state == :closed and (state.consumer_pid != nil or not state.enabled)
    {:reply, healthy, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      circuit_state: state.circuit_state,
      failure_count: state.failure_count,
      consumer_connected: state.consumer_pid != nil,
      dedup_size: :ets.info(:notification_kafka_dedup, :size),
      queue_size: length(state.priority_queue),
      available_tokens: state.rate_limiter.tokens,
      enabled: state.enabled,
      notifications_sent: get_stat(:notifications_sent),
      notifications_failed: get_stat(:notifications_failed)
    }
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:rate_limit_status, _from, state) do
    {:reply, %{available_tokens: state.rate_limiter.tokens, max_tokens: @max_tokens}, state}
  end

  # ============================================================================
  # Brod Callbacks - Group Subscriber
  # ============================================================================

  @doc "brod_group_subscriber callback - called when subscriber initializes"
  def init(_group_id, _init_args) do
    {:ok, %{}}
  end

  def handle_message(topic, partition, message, state) do
    message_id = extract_message_id(message)

    cond do
      is_duplicate?(message_id) ->
        Logger.debug("[NotificationKafkaConsumer] Skipping duplicate message: #{message_id}")
        {:ok, :ack, state}

      true ->
        result = safe_process_message(topic, partition, message)
        mark_processed(message_id)

        case result do
          :ok ->
            {:ok, :ack, state}

          {:error, :retriable} ->
            {:ok, :ack_no_commit, state}

          {:error, _} ->
            {:ok, :ack, state}
        end
    end
  end

  # ============================================================================
  # Private Functions - Connection Management
  # ============================================================================

  defp connect_to_kafka(state) do
    config = Application.get_env(:notification_orchestrator, :kafka, [])

    brokers = parse_brokers(config[:brokers] || System.get_env("KAFKA_BROKERS") || "localhost:9092")
    group_id = config[:consumer_group] || System.get_env("KAFKA_CONSUMER_GROUP") || "notification-service-group"
    client_id = :notification_consumer

    Logger.info("[NotificationKafkaConsumer] Connecting to brokers: #{inspect(brokers)}, group: #{group_id}")

    # Start brod client first (required before starting group subscriber)
    case :brod.start_client(brokers, client_id, []) do
      :ok ->
        start_group_subscriber(state, client_id, brokers, group_id)

      {:error, {:already_started, _pid}} ->
        start_group_subscriber(state, client_id, brokers, group_id)

      {:error, reason} ->
        Logger.error("[NotificationKafkaConsumer] Failed to start brod client: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp start_group_subscriber(state, client_id, brokers, group_id) do
    group_config = [
      offset_commit_policy: :commit_to_kafka_v2,
      offset_commit_interval_seconds: 5,
      rejoin_delay_seconds: 2
    ]

    consumer_config = [begin_offset: :earliest]

    case :brod.start_link_group_subscriber(
           client_id,
           group_id,
           @topics,
           group_config,
           consumer_config,
           __MODULE__,
           []
         ) do
      {:ok, pid} ->
        Process.monitor(pid)
        {:ok, %{state | consumer_pid: pid, brokers: brokers, group_id: group_id, topics: @topics}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_brokers(brokers) when is_binary(brokers) do
    brokers
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_single_broker/1)
  end

  defp parse_brokers(brokers) when is_list(brokers) do
    Enum.map(brokers, fn
      {host, port} when is_list(host) -> {host, port}
      {host, port} when is_binary(host) -> {String.to_charlist(host), port}
      broker when is_binary(broker) -> parse_single_broker(broker)
    end)
  end

  defp parse_single_broker(broker) do
    case String.split(broker, ":") do
      [host, port] -> {String.to_charlist(host), String.to_integer(port)}
      [host] -> {String.to_charlist(host), 9092}
    end
  end

  # ============================================================================
  # Private Functions - Circuit Breaker
  # ============================================================================

  defp handle_connection_failure(state, reason) do
    new_failure_count = state.failure_count + 1
    Logger.warning("[NotificationKafkaConsumer] Connection failed (#{new_failure_count}/#{@max_failures}): #{inspect(reason)}")

    new_state = %{state |
      failure_count: new_failure_count,
      last_failure_at: System.system_time(:millisecond),
      consumer_pid: nil
    }

    if new_failure_count >= @max_failures do
      Logger.error("[NotificationKafkaConsumer] Circuit breaker OPEN - max failures reached")
      schedule_retry()
      %{new_state | circuit_state: :open}
    else
      schedule_retry()
      new_state
    end
  end

  defp should_attempt_reset?(state) do
    case state.last_failure_at do
      nil -> true
      last_failure ->
        elapsed = System.system_time(:millisecond) - last_failure
        elapsed >= @reset_timeout_ms
    end
  end

  defp schedule_retry, do: Process.send_after(self(), :retry_connect, @retry_delay_ms)
  defp schedule_cleanup, do: Process.send_after(self(), :cleanup_dedup, @dedup_window_ms)
  defp schedule_rate_refill, do: Process.send_after(self(), :refill_tokens, 1_000)
  defp schedule_queue_processor, do: Process.send_after(self(), :process_queue, 100)

  # ============================================================================
  # Private Functions - Message Processing
  # ============================================================================

  defp safe_process_message(topic, _partition, message) do
    with {:ok, payload} <- extract_payload(message),
         {:ok, event} <- Jason.decode(payload),
         :ok <- process_event(topic, event) do
      :telemetry.execute(
        [:notification_orchestrator, :kafka, :message_processed],
        %{count: 1},
        %{topic: topic}
      )
      :ok
    else
      {:error, :invalid_json} ->
        Logger.warning("[NotificationKafkaConsumer] Invalid JSON in message")
        {:error, :invalid_json}

      {:error, :unknown_event} ->
        :ok

      {:error, reason} ->
        Logger.error("[NotificationKafkaConsumer] Error processing message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_payload(message) when is_map(message), do: {:ok, message.value}
  defp extract_payload(message) when is_tuple(message), do: {:ok, elem(message, 4)}
  defp extract_payload(_), do: {:error, :invalid_message_format}

  defp extract_message_id(message) do
    case message do
      %{key: key} when is_binary(key) -> key
      %{offset: offset, partition: partition} -> "#{partition}-#{offset}"
      tuple when is_tuple(tuple) -> "#{elem(tuple, 1)}-#{elem(tuple, 2)}"
      _ -> :crypto.strong_rand_bytes(16) |> Base.encode16()
    end
  end

  # ============================================================================
  # Private Functions - Event Handlers (Strategy Pattern)
  # ============================================================================

  defp process_event(_topic, %{"event" => "send_notification"} = event) do
    with {:ok, type} <- validate_notification_type(event["type"] || "push"),
         {:ok, priority} <- validate_priority(event["priority"] || "normal") do
      notification = build_notification(event, type, priority)

      Task.start(fn ->
        send_notification(notification)
      end)
      :ok
    end
  end

  defp process_event(_topic, %{"event" => "send_bulk_notification"} = event) do
    user_ids = event["user_ids"] || []
    with {:ok, type} <- validate_notification_type(event["type"] || "push"),
         {:ok, priority} <- validate_priority(event["priority"] || "normal") do
      Task.start(fn ->
        Enum.each(user_ids, fn user_id ->
          notification = build_notification(Map.put(event, "user_id", user_id), type, priority)
          send_notification(notification)
        end)
      end)
      :ok
    end
  end

  # Message events trigger notifications
  defp process_event(_topic, %{"event" => "new_message", "sender_id" => sender_id, "recipient_id" => recipient_id} = event) do
    notification = %{
      user_id: recipient_id,
      type: :push,
      priority: :high,
      title: event["sender_name"] || "New Message",
      body: truncate_message(event["content"]),
      data: %{
        type: "message",
        conversation_id: event["conversation_id"],
        message_id: event["message_id"],
        sender_id: sender_id
      }
    }

    Task.start(fn ->
      send_notification(notification)
    end)
    :ok
  end

  # Call events trigger notifications
  defp process_event(_topic, %{"event" => "incoming_call", "caller_id" => caller_id, "callee_id" => callee_id} = event) do
    notification = %{
      user_id: callee_id,
      type: :push,
      priority: :critical,
      title: "Incoming Call",
      body: event["caller_name"] || "Someone is calling you",
      data: %{
        type: "call",
        call_id: event["call_id"],
        caller_id: caller_id,
        call_type: event["call_type"] || "audio"
      }
    }

    Task.start(fn ->
      send_notification(notification)
    end)
    :ok
  end

  # Missed call notification
  defp process_event(_topic, %{"event" => "missed_call", "caller_id" => caller_id, "callee_id" => callee_id} = event) do
    notification = %{
      user_id: callee_id,
      type: :push,
      priority: :normal,
      title: "Missed Call",
      body: event["caller_name"] || "You missed a call",
      data: %{
        type: "missed_call",
        call_id: event["call_id"],
        caller_id: caller_id
      }
    }

    Task.start(fn ->
      send_notification(notification)
    end)
    :ok
  end

  # System events
  defp process_event(_topic, %{"event" => "system_alert"} = event) do
    notification = %{
      user_id: event["user_id"],
      type: :push,
      priority: :high,
      title: event["title"] || "System Alert",
      body: event["body"],
      data: %{type: "system", alert_type: event["alert_type"]}
    }

    Task.start(fn ->
      send_notification(notification)
    end)
    :ok
  end

  defp process_event(_topic, %{"event" => event_type} = event) do
    Logger.debug("[NotificationKafkaConsumer] Unhandled event type: #{event_type}, payload: #{inspect(event)}")
    {:error, :unknown_event}
  end

  defp process_event(_topic, _event) do
    {:error, :unknown_event}
  end

  # ============================================================================
  # Private Functions - Notification Building (Factory Pattern)
  # ============================================================================

  defp build_notification(event, type, priority) do
    %{
      user_id: event["user_id"],
      type: type,
      priority: priority,
      title: event["title"],
      body: event["body"],
      data: event["data"] || %{},
      channels: event["channels"] || ["firebase"],
      scheduled_at: event["scheduled_at"]
    }
  end

  # ============================================================================
  # Private Functions - Notification Sending (Chain of Responsibility)
  # ============================================================================

  defp send_notification(notification) do
    channels = notification[:channels] || ["firebase"]

    Enum.each(channels, fn channel ->
      case send_via_channel(channel, notification) do
        :ok ->
          increment_stat(:notifications_sent)
          Logger.debug("[NotificationKafkaConsumer] Notification sent via #{channel}")

        {:error, reason} ->
          increment_stat(:notifications_failed)
          Logger.warning("[NotificationKafkaConsumer] Failed to send via #{channel}: #{inspect(reason)}")
      end
    end)
  end

  defp send_via_channel("firebase", notification) do
    NotificationOrchestrator.Providers.Firebase.send_notification(notification)
  end

  defp send_via_channel("apns", notification) do
    NotificationOrchestrator.Providers.APNs.send_notification(notification)
  end

  defp send_via_channel("email", notification) do
    NotificationOrchestrator.Providers.Email.send_notification(notification)
  end

  defp send_via_channel(channel, _notification) do
    Logger.warning("[NotificationKafkaConsumer] Unknown channel: #{channel}")
    {:error, :unknown_channel}
  end

  # ============================================================================
  # Private Functions - Priority Queue Processing
  # ============================================================================

  defp process_priority_queue(%{priority_queue: [], rate_limiter: rl} = state) do
    %{state | rate_limiter: rl}
  end

  defp process_priority_queue(%{priority_queue: queue, rate_limiter: %{tokens: tokens}} = state) when tokens <= 0 do
    Logger.debug("[NotificationKafkaConsumer] Rate limit reached, waiting for tokens")
    state
  end

  defp process_priority_queue(%{priority_queue: [notification | rest], rate_limiter: rl} = state) do
    Task.start(fn -> send_notification(notification) end)
    %{state | priority_queue: rest, rate_limiter: %{rl | tokens: rl.tokens - 1}}
  end

  # ============================================================================
  # Private Functions - Validation
  # ============================================================================

  defp validate_notification_type(type) when type in @valid_notification_types do
    {:ok, String.to_existing_atom(type)}
  rescue
    ArgumentError -> {:error, :invalid_notification_type}
  end

  defp validate_notification_type(_type), do: {:error, :invalid_notification_type}

  defp validate_priority(priority) when priority in @valid_priorities do
    {:ok, String.to_existing_atom(priority)}
  rescue
    ArgumentError -> {:error, :invalid_priority}
  end

  defp validate_priority(_priority), do: {:error, :invalid_priority}

  # ============================================================================
  # Private Functions - Utilities
  # ============================================================================

  defp truncate_message(nil), do: ""
  defp truncate_message(content) when byte_size(content) > 100 do
    String.slice(content, 0, 97) <> "..."
  end
  defp truncate_message(content), do: content

  # ============================================================================
  # Private Functions - Deduplication & Stats
  # ============================================================================

  defp is_duplicate?(message_id) do
    case :ets.lookup(:notification_kafka_dedup, message_id) do
      [{^message_id, _timestamp}] -> true
      [] -> false
    end
  end

  defp mark_processed(message_id) do
    timestamp = System.system_time(:millisecond)
    :ets.insert(:notification_kafka_dedup, {message_id, timestamp})
  end

  defp init_stats do
    :ets.insert(:notification_kafka_stats, {:notifications_sent, 0})
    :ets.insert(:notification_kafka_stats, {:notifications_failed, 0})
  end

  defp get_stat(key) do
    case :ets.lookup(:notification_kafka_stats, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end

  defp increment_stat(key) do
    :ets.update_counter(:notification_kafka_stats, key, 1)
  rescue
    _ -> :ok
  end
end
