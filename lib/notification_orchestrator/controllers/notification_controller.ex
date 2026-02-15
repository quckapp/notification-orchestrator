defmodule NotificationOrchestrator.NotificationController do
  use Phoenix.Controller, formats: [:json]
  use OpenApiSpex.ControllerSpecs

  alias NotificationOrchestrator.Schemas.Notification
  alias NotificationOrchestrator.Schemas.Common

  tags ["Notifications"]
  security [%{"bearer_auth" => []}]

  operation :send,
    summary: "Send notification",
    description: "Send a notification to a specific user through configured channels (push, in-app, email, SMS)",
    request_body: {"Notification details", "application/json", Notification.SendNotificationRequest},
    responses: [
      ok: {"Notification sent successfully", "application/json", Notification.SendNotificationResponse},
      bad_request: {"Invalid request", "application/json", Common.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

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

  operation :send_bulk,
    summary: "Send bulk notifications",
    description: "Send the same notification to multiple users at once. Maximum 1000 users per request.",
    request_body: {"Bulk notification details", "application/json", Notification.BulkNotificationRequest},
    responses: [
      ok: {"Bulk notifications sent", "application/json", Notification.BulkNotificationResponse},
      bad_request: {"Invalid request", "application/json", Common.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

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

  operation :index,
    summary: "List notifications",
    description: "Retrieve a list of notifications for the authenticated user",
    parameters: [
      limit: [
        in: :query,
        type: :integer,
        description: "Maximum number of notifications to return",
        example: 50
      ],
      unread_only: [
        in: :query,
        type: :boolean,
        description: "If true, only return unread notifications",
        example: false
      ]
    ],
    responses: [
      ok: {"List of notifications", "application/json", Notification.NotificationListResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

  def index(conn, params) do
    user_id = conn.assigns[:current_user_id]
    opts = [
      limit: String.to_integer(Map.get(params, "limit", "50")),
      unread_only: Map.get(params, "unread_only", "false") == "true"
    ]
    {:ok, notifications} = NotificationOrchestrator.NotificationManager.get_notifications(user_id, opts)
    json(conn, %{success: true, data: notifications})
  end

  operation :unread_count,
    summary: "Get unread count",
    description: "Get the count of unread notifications for the authenticated user",
    responses: [
      ok: {"Unread count", "application/json", Notification.UnreadCountResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

  def unread_count(conn, _params) do
    user_id = conn.assigns[:current_user_id]
    {:ok, count} = NotificationOrchestrator.NotificationManager.get_unread_count(user_id)
    json(conn, %{success: true, data: %{count: count}})
  end

  operation :mark_read,
    summary: "Mark notifications as read",
    description: "Mark one or more notifications as read for the authenticated user",
    request_body: {"Notification IDs to mark as read", "application/json", Notification.MarkReadRequest},
    responses: [
      ok: {"Notifications marked as read", "application/json", Common.SuccessResponse},
      bad_request: {"Invalid request", "application/json", Common.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

  def mark_read(conn, %{"notification_ids" => ids}) do
    user_id = conn.assigns[:current_user_id]
    NotificationOrchestrator.NotificationManager.mark_as_read(ids, user_id)
    json(conn, %{success: true})
  end

  defp parse_channels(channels) when is_list(channels) do
    Enum.map(channels, &String.to_existing_atom/1)
  end
end
