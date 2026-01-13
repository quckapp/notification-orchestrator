defmodule NotificationOrchestrator.Providers.APNs do
  use GenServer
  require Logger

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def send(device_token, notification) do
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

    # In production, use Pigeon or similar library for APNs
    Logger.info("APNs notification would be sent to #{device_token}")
    :telemetry.execute([:notification, :apns, :sent], %{count: 1}, %{})

    {:noreply, state}
  end
end
