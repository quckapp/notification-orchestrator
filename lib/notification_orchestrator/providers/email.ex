defmodule NotificationOrchestrator.Providers.Email do
  use GenServer
  require Logger

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def send(user_id, notification) do
    GenServer.cast(__MODULE__, {:send, user_id, notification})
  end

  @impl true
  def init(_state), do: {:ok, %{}}

  @impl true
  def handle_cast({:send, user_id, notification}, state) do
    # Get user email from user service
    case get_user_email(user_id) do
      {:ok, email} ->
        send_email(email, notification)
        :telemetry.execute([:notification, :email, :sent], %{count: 1}, %{})
      {:error, _} ->
        Logger.warning("Could not get email for user #{user_id}")
    end

    {:noreply, state}
  end

  defp get_user_email(_user_id) do
    # Call user service to get email
    {:ok, "user@example.com"}
  end

  defp send_email(email, notification) do
    # Implement email sending via SMTP or service like SendGrid
    Logger.info("Email notification would be sent to #{email}: #{notification.title}")
  end
end
