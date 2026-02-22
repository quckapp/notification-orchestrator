defmodule NotificationOrchestrator.Schemas.Device do
  @moduledoc """
  Device-related schemas for the API.
  """

  alias OpenApiSpex.Schema

  defmodule RegisterDeviceRequest do
    @moduledoc "Request schema for registering a device"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "RegisterDeviceRequest",
      description: "Request body for registering a device for push notifications",
      type: :object,
      properties: %{
        token: %Schema{
          type: :string,
          description: "The push notification token (FCM token for Android, APNs token for iOS)"
        },
        platform: %Schema{
          type: :string,
          description: "The device platform",
          enum: ["ios", "android", "web"]
        },
        device_name: %Schema{
          type: :string,
          description: "A human-readable name for the device",
          default: "Unknown"
        },
        metadata: %Schema{
          type: :object,
          description: "Additional metadata about the device",
          properties: %{
            os_version: %Schema{type: :string, description: "Operating system version"},
            app_version: %Schema{type: :string, description: "Application version"},
            device_model: %Schema{type: :string, description: "Device model name"},
            locale: %Schema{type: :string, description: "Device locale/language"}
          },
          additionalProperties: true
        }
      },
      required: [:token, :platform],
      example: %{
        token: "fcm_token_abc123xyz...",
        platform: "android",
        device_name: "John's Pixel 7",
        metadata: %{
          os_version: "Android 14",
          app_version: "2.1.0",
          device_model: "Pixel 7 Pro",
          locale: "en-US"
        }
      }
    })
  end

  defmodule DeviceResponse do
    @moduledoc "Response schema for a device"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceResponse",
      description: "A registered device object",
      type: :object,
      properties: %{
        device_id: %Schema{type: :string, format: :uuid, description: "Unique device identifier"},
        platform: %Schema{
          type: :string,
          description: "The device platform",
          enum: ["ios", "android", "web"]
        },
        token: %Schema{type: :string, description: "The push notification token"},
        device_name: %Schema{type: :string, description: "Human-readable device name"},
        last_active: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the device was last active"
        },
        registered_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the device was registered"
        }
      },
      required: [:device_id, :platform, :token],
      example: %{
        device_id: "550e8400-e29b-41d4-a716-446655440000",
        platform: "android",
        token: "fcm_token_abc123xyz...",
        device_name: "John's Pixel 7",
        last_active: "2024-01-15T10:30:00Z",
        registered_at: "2024-01-01T08:00:00Z"
      }
    })
  end

  defmodule RegisterDeviceResponse do
    @moduledoc "Response schema for device registration"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "RegisterDeviceResponse",
      description: "Response after registering a device",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful"},
        data: %Schema{
          type: :object,
          properties: %{
            device_id: %Schema{type: :string, format: :uuid, description: "The assigned device ID"}
          },
          required: [:device_id]
        }
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: %{
          device_id: "550e8400-e29b-41d4-a716-446655440000"
        }
      }
    })
  end

  defmodule DeviceListResponse do
    @moduledoc "Response schema for listing devices"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceListResponse",
      description: "Response containing a list of registered devices",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful"},
        data: %Schema{
          type: :array,
          description: "List of registered devices",
          items: NotificationOrchestrator.Schemas.Device.DeviceResponse
        }
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: [
          %{
            device_id: "550e8400-e29b-41d4-a716-446655440000",
            platform: "android",
            token: "fcm_token_abc123xyz...",
            device_name: "John's Pixel 7",
            last_active: "2024-01-15T10:30:00Z"
          }
        ]
      }
    })
  end
end
