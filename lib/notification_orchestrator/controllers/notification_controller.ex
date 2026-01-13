defmodule NotificationOrchestrator.NotificationController do
  use Phoenix.Controller, formats: [:json]

  def send(conn, %{"user_id" => user_id, "type" => type, "title" => title, "body" => body} = params) do
    type_atom = String.to_existing_atom(type)
    opts = [
      priority: String.to_existing_atom(Map.get(params, "priority", "normal")),
      data: Map.get(params, "data", %{}),
      channels: parse_channels(Map.get(params, "channels", ["push", "in_app"]))
    ]
    
    case NotificationOrchestrator.NotificationManager.send_notification(user_id, type_atom, title, body, opts) do
      {:ok, notification} -> json(conn, %{success: true, data: notification})
      {:error, reason} -> conn |> put_status(400) |> json(%{success: false, error: reason})
    end
  end

  def send_bulk(conn, %{"user_ids" => user_ids, "type" => type, "title" => title, "body" => body} = params) do
    type_atom = String.to_existing_atom(type)
    opts = [
      priority: String.to_existing_atom(Map.get(params, "priority", "normal")),
      data: Map.get(params, "data", %{})
    ]
    
    case NotificationOrchestrator.NotificationManager.send_bulk(user_ids, type_atom, title, body, opts) do
      {:ok, result} -> json(conn, %{success: true, data: result})
      {:error, reason} -> conn |> put_status(400) |> json(%{success: false, error: reason})
    end
  end

  def index(conn, params) do
    user_id = conn.assigns[:current_user_id]
    opts = [
      limit: String.to_integer(Map.get(params, "limit", "50")),
      unread_only: Map.get(params, "unread_only", "false") == "true"
    ]
    {:ok, notifications} = NotificationOrchestrator.NotificationManager.get_notifications(user_id, opts)
    json(conn, %{success: true, data: notifications})
  end

  def unread_count(conn, _params) do
    user_id = conn.assigns[:current_user_id]
    {:ok, count} = NotificationOrchestrator.NotificationManager.get_unread_count(user_id)
    json(conn, %{success: true, data: %{count: count}})
  end

  def mark_read(conn, %{"notification_ids" => ids}) do
    user_id = conn.assigns[:current_user_id]
    NotificationOrchestrator.NotificationManager.mark_as_read(ids, user_id)
    json(conn, %{success: true})
  end

  defp parse_channels(channels) when is_list(channels) do
    Enum.map(channels, &String.to_existing_atom/1)
  end
end
