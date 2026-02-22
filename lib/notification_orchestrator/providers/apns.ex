defmodule NotificationOrchestrator.Providers.APNs do
  use GenServer
  require Logger

  alias NotificationOrchestrator.CircuitBreaker

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Send notification (extracts device_token from notification map)"
  def send_notification(notification) when is_map(notification) do
    device_token = notification[:device_token] || notification["device_token"]
    send_notification(device_token, notification)
  end

  @doc "Send notification to device token"
  def send_notification(device_token, notification) do
    GenServer.cast(__MODULE__, {:send, device_token, notification})
  end

  @impl true
  def init(_state) do
    config = Application.get_env(:notification_orchestrator, :apns)
    {:ok, %{key_id: config[:key_id], team_id: config[:team_id]}}
  end

  @impl true
  def handle_cast({:send, device_token, notification}, state) do
    payload = %{
      aps: %{
        alert: %{
          title: notification.title,
          body: notification.body
        },
        badge: 1,
        sound: "default"
      },
      data: notification.data
    }

    # Wrap APNs call with circuit breaker
    CircuitBreaker.call(:apns, fn ->
      # In production, use Pigeon or similar library for APNs
      Logger.info("APNs notification would be sent to #{device_token}")
      :telemetry.execute([:notification, :apns, :sent], %{count: 1}, %{})
      {:ok, :sent}
    end, default: {:error, :circuit_open})

    {:noreply, state}
  end
end
