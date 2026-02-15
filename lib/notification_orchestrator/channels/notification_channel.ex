defmodule NotificationOrchestrator.NotificationChannel do
  @moduledoc """
  Phoenix channel for real-time notification delivery.

  Users subscribe to their notification channel to receive push notifications
  in real-time when connected via WebSocket.
  """
  use Phoenix.Channel
  require Logger

  @impl true
  def join("notification:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      Logger.debug("[NotificationChannel] User #{user_id} joined notification channel")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("ack", %{"notification_id" => notification_id}, socket) do
    # Acknowledge receipt of notification
    Logger.debug("[NotificationChannel] Notification #{notification_id} acknowledged by user #{socket.assigns.user_id}")
    {:reply, :ok, socket}
  end

  @impl true
  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @doc """
  Broadcast a notification to a specific user.
  """
  def push_notification(user_id, notification) do
    Phoenix.PubSub.broadcast(
      NotificationOrchestrator.PubSub,
      "notification:#{user_id}",
      {:notification, notification}
    )
  end
end
