defmodule NotificationOrchestrator.Schemas.Notification do
  @moduledoc """
  Notification-related schemas for the API.
  """

  alias OpenApiSpex.Schema

  defmodule SendNotificationRequest do
    @moduledoc "Request schema for sending a single notification"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SendNotificationRequest",
      description: "Request body for sending a notification to a user",
      type: :object,
      properties: %{
        user_id: %Schema{type: :string, description: "The ID of the user to send the notification to"},
        type: %Schema{
          type: :string,
          description: "The type of notification",
          enum: ["info", "warning", "alert", "promotion", "system"]
        },
        title: %Schema{type: :string, description: "The notification title"},
        body: %Schema{type: :string, description: "The notification body/message"},
        priority: %Schema{
          type: :string,
          description: "Notification priority level",
          enum: ["low", "normal", "high"],
          default: "normal"
        },
        data: %Schema{
          type: :object,
          description: "Additional custom data to include with the notification",
          additionalProperties: true
        },
        channels: %Schema{
          type: :array,
          description: "Delivery channels for the notification",
          items: %Schema{type: :string, enum: ["push", "in_app", "email", "sms"]},
          default: ["push", "in_app"]
        }
      },
      required: [:user_id, :type, :title, :body],
      example: %{
        user_id: "user_123",
        type: "info",
        title: "New Message",
        body: "You have received a new message from John",
        priority: "normal",
        data: %{
          message_id: "msg_456",
          sender: "john@example.com"
        },
        channels: ["push", "in_app"]
      }
    })
  end

  defmodule BulkNotificationRequest do
    @moduledoc "Request schema for sending bulk notifications"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BulkNotificationRequest",
      description: "Request body for sending notifications to multiple users",
      type: :object,
      properties: %{
        user_ids: %Schema{
          type: :array,
          description: "List of user IDs to send the notification to",
          items: %Schema{type: :string},
          minItems: 1,
          maxItems: 1000
        },
        type: %Schema{
          type: :string,
          description: "The type of notification",
          enum: ["info", "warning", "alert", "promotion", "system"]
        },
        title: %Schema{type: :string, description: "The notification title"},
        body: %Schema{type: :string, description: "The notification body/message"},
        priority: %Schema{
          type: :string,
          description: "Notification priority level",
          enum: ["low", "normal", "high"],
          default: "normal"
        },
        data: %Schema{
          type: :object,
          description: "Additional custom data to include with the notification",
          additionalProperties: true
        },
        channels: %Schema{
          type: :array,
          description: "Delivery channels for the notification",
          items: %Schema{type: :string, enum: ["push", "in_app", "email", "sms"]},
          default: ["push", "in_app"]
        }
      },
      required: [:user_ids, :type, :title, :body],
      example: %{
        user_ids: ["user_123", "user_456", "user_789"],
        type: "promotion",
        title: "Special Offer",
        body: "Get 20% off your next purchase!",
        priority: "normal",
        data: %{
          promotion_id: "promo_001",
          expires_at: "2024-02-01T00:00:00Z"
        },
        channels: ["push", "in_app", "email"]
      }
    })
  end

  defmodule NotificationResponse do
    @moduledoc "Response schema for a notification"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NotificationResponse",
      description: "A notification object",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Unique notification identifier"},
        user_id: %Schema{type: :string, description: "The user ID this notification belongs to"},
        type: %Schema{type: :string, description: "The type of notification"},
        title: %Schema{type: :string, description: "The notification title"},
        body: %Schema{type: :string, description: "The notification body/message"},
        read: %Schema{type: :boolean, description: "Whether the notification has been read"},
        data: %Schema{
          type: :object,
          description: "Additional custom data included with the notification",
          additionalProperties: true
        },
        created_at: %Schema{type: :string, format: :"date-time", description: "When the notification was created"},
        updated_at: %Schema{type: :string, format: :"date-time", description: "When the notification was last updated"}
      },
      required: [:id, :user_id, :title, :body, :read],
      example: %{
        id: "notif_abc123",
        user_id: "user_123",
        type: "info",
        title: "New Message",
        body: "You have received a new message from John",
        read: false,
        data: %{
          message_id: "msg_456"
        },
        created_at: "2024-01-15T10:30:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule NotificationListResponse do
    @moduledoc "Response schema for a list of notifications"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NotificationListResponse",
      description: "Response containing a list of notifications",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful"},
        data: %Schema{
          type: :array,
          description: "List of notifications",
          items: NotificationOrchestrator.Schemas.Notification.NotificationResponse
        }
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: [
          %{
            id: "notif_abc123",
            user_id: "user_123",
            type: "info",
            title: "New Message",
            body: "You have received a new message",
            read: false,
            created_at: "2024-01-15T10:30:00Z"
          }
        ]
      }
    })
  end

  defmodule SendNotificationResponse do
    @moduledoc "Response schema for sending a notification"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SendNotificationResponse",
      description: "Response after sending a notification",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful"},
        data: NotificationOrchestrator.Schemas.Notification.NotificationResponse
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: %{
          id: "notif_abc123",
          user_id: "user_123",
          type: "info",
          title: "New Message",
          body: "You have received a new message",
          read: false,
          created_at: "2024-01-15T10:30:00Z"
        }
      }
    })
  end

  defmodule BulkNotificationResponse do
    @moduledoc "Response schema for bulk notification sending"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BulkNotificationResponse",
      description: "Response after sending bulk notifications",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful"},
        data: %Schema{
          type: :object,
          properties: %{
            sent: %Schema{type: :integer, description: "Number of notifications successfully sent"},
            failed: %Schema{type: :integer, description: "Number of notifications that failed to send"},
            notification_ids: %Schema{
              type: :array,
              description: "List of created notification IDs",
              items: %Schema{type: :string}
            }
          }
        }
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: %{
          sent: 3,
          failed: 0,
          notification_ids: ["notif_001", "notif_002", "notif_003"]
        }
      }
    })
  end

  defmodule UnreadCountResponse do
    @moduledoc "Response schema for unread notification count"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UnreadCountResponse",
      description: "Response containing the count of unread notifications",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful"},
        data: %Schema{
          type: :object,
          properties: %{
            count: %Schema{type: :integer, description: "Number of unread notifications", minimum: 0}
          },
          required: [:count]
        }
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: %{
          count: 5
        }
      }
    })
  end

  defmodule MarkReadRequest do
    @moduledoc "Request schema for marking notifications as read"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MarkReadRequest",
      description: "Request body for marking notifications as read",
      type: :object,
      properties: %{
        notification_ids: %Schema{
          type: :array,
          description: "List of notification IDs to mark as read",
          items: %Schema{type: :string},
          minItems: 1
        }
      },
      required: [:notification_ids],
      example: %{
        notification_ids: ["notif_001", "notif_002", "notif_003"]
      }
    })
  end
end
