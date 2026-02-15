defmodule NotificationOrchestrator.Distribution do
  @moduledoc """
  Consistent hashing for notification orchestrator using ex_hash_ring.

  Provides consistent distribution of:
  - Kafka partition selection for notification events
  - Worker assignment for notification processing
  - Load balancing across notification providers

  ## Usage:

      # Get the Kafka partition for a notification
      partition = Distribution.get_partition(user_id)

      # Get the worker for processing a notification batch
      worker = Distribution.get_worker(batch_id)
  """

  use GenServer
  require Logger

  @default_replicas 256
  @default_partition_count 3
  @default_worker_count 4

  # Ring names
  @partition_ring NotificationOrchestrator.Distribution.PartitionRing
  @worker_ring NotificationOrchestrator.Distribution.WorkerRing
  @node_ring NotificationOrchestrator.Distribution.NodeRing

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the Kafka partition for a given key.
  """
  def get_partition(key, partition_count \\ @default_partition_count) do
    if partition_count != @default_partition_count do
      :erlang.phash2(key, partition_count)
    else
      case ExHashRing.Ring.find_node(@partition_ring, to_string(key)) do
        {:ok, partition} -> partition
        _ -> :erlang.phash2(key, partition_count)
      end
    end
  end

  @doc """
  Get the worker index for a given batch.
  """
  def get_worker(key) do
    case ExHashRing.Ring.find_node(@worker_ring, to_string(key)) do
      {:ok, worker} -> worker
      _ -> :rand.uniform(worker_count()) - 1
    end
  end

  @doc """
  Get the notification provider for a given device.
  Used for load balancing across multiple provider connections.
  """
  def get_provider_instance(provider, device_id) do
    key = "#{provider}:#{device_id}"
    case ExHashRing.Ring.find_node(@worker_ring, key) do
      {:ok, instance} -> instance
      _ -> 0
    end
  end

  @doc """
  Get the node for handling a notification.
  """
  def get_node(key) do
    case ExHashRing.Ring.find_node(@node_ring, to_string(key)) do
      {:ok, node_name} -> node_name
      _ -> node()
    end
  end

  @doc """
  Get ring status.
  """
  def status do
    nodes = case ExHashRing.Ring.get_nodes(@node_ring) do
      {:ok, nodes} -> nodes
      _ -> []
    end

    %{
      nodes: nodes,
      partitions: @default_partition_count,
      workers: worker_count(),
      replicas: @default_replicas
    }
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Start the hash rings
    start_rings()

    # Subscribe to node up/down events
    :net_kernel.monitor_nodes(true)

    Logger.info("[Distribution] Initialized with #{@default_replicas} replicas")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:nodeup, node_name}, state) do
    case ExHashRing.Ring.add_node(@node_ring, node_name) do
      :ok -> Logger.info("[Distribution] Node joined: #{node_name}")
      _ -> :ok
    end
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node_name}, state) do
    case ExHashRing.Ring.remove_node(@node_ring, node_name) do
      :ok -> Logger.info("[Distribution] Node left: #{node_name}")
      _ -> :ok
    end
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp start_rings do
    # Partition ring
    partition_nodes = for i <- 0..(@default_partition_count - 1), do: i
    start_ring(@partition_ring, partition_nodes)

    # Worker ring
    worker_nodes = for i <- 0..(worker_count() - 1), do: i
    start_ring(@worker_ring, worker_nodes)

    # Node ring with current cluster nodes
    cluster_nodes = [node() | Node.list()]
    start_ring(@node_ring, cluster_nodes)
  end

  defp start_ring(name, nodes) do
    case ExHashRing.Ring.start_link(
      name: name,
      nodes: nodes,
      replicas: @default_replicas
    ) do
      {:ok, _pid} ->
        Logger.debug("[Distribution] Started ring #{name} with nodes: #{inspect(nodes)}")
        :ok
      {:error, {:already_started, _pid}} ->
        ExHashRing.Ring.set_nodes(name, nodes)
        :ok
      error ->
        Logger.error("[Distribution] Failed to start ring #{name}: #{inspect(error)}")
        error
    end
  end

  defp worker_count do
    Application.get_env(:notification_orchestrator, :worker_count, @default_worker_count)
  end
end
