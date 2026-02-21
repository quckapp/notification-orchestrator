defmodule NotificationOrchestrator.NotificationChannel do
  use Phoenix.Channel
  require Logger

  @impl true
  def join("notifications:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    push(socket, "new_notification", %{notification: notification})
    {:noreply, socket}
  end

  @impl true
  def handle_in("mark_read", %{"notification_ids" => ids}, socket) do
    user_id = socket.assigns.user_id
    NotificationOrchestrator.NotificationManager.mark_as_read(ids, user_id)
    {:reply, :ok, socket}
  end
end
