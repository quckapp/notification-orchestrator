defmodule NotificationOrchestrator.Providers.Firebase do
  use GenServer
  require Logger

  @fcm_url "https://fcm.googleapis.com/v1/projects"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def send(device_token, notification) do
    GenServer.cast(__MODULE__, {:send, device_token, notification})
  end

  @impl true
  def init(_state) do
    config = Application.get_env(:notification_orchestrator, :firebase)
    {:ok, %{project_id: config[:project_id], access_token: nil, token_expires_at: nil}}
  end

  @impl true
  def handle_cast({:send, device_token, notification}, state) do
    state = ensure_access_token(state)
    
    payload = %{
      message: %{
        token: device_token,
        notification: %{
          title: notification.title,
          body: notification.body
        },
        data: notification.data,
        android: %{priority: priority_to_android(notification.priority)},
        apns: %{headers: %{"apns-priority" => priority_to_apns(notification.priority)}}
      }
    }

    url = "#{@fcm_url}/#{state.project_id}/messages:send"
    
    case Req.post(url,
      json: payload,
      headers: [{"Authorization", "Bearer #{state.access_token}"}]
    ) do
      {:ok, %{status: 200}} ->
        :telemetry.execute([:notification, :firebase, :sent], %{count: 1}, %{})
        Logger.debug("Firebase notification sent to #{device_token}")
      {:ok, %{status: status, body: body}} ->
        Logger.warning("Firebase notification failed: #{status} - #{inspect(body)}")
        :telemetry.execute([:notification, :failed], %{count: 1}, %{provider: :firebase})
      {:error, reason} ->
        Logger.error("Firebase notification error: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp ensure_access_token(%{access_token: token, token_expires_at: expires} = state) 
       when not is_nil(token) and not is_nil(expires) do
    if DateTime.compare(DateTime.utc_now(), expires) == :lt do
      state
    else
      refresh_access_token(state)
    end
  end
  defp ensure_access_token(state), do: refresh_access_token(state)

  defp refresh_access_token(state) do
    # In production, use service account JWT to get access token
    # This is a placeholder - implement OAuth2 service account flow
    %{state | access_token: "placeholder_token", token_expires_at: DateTime.add(DateTime.utc_now(), 3600)}
  end

  defp priority_to_android(:high), do: "high"
  defp priority_to_android(_), do: "normal"

  defp priority_to_apns(:high), do: "10"
  defp priority_to_apns(_), do: "5"
end
