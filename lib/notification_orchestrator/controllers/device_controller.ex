defmodule NotificationOrchestrator.DeviceController do
  use Phoenix.Controller, formats: [:json]
  use OpenApiSpex.ControllerSpecs

  alias NotificationOrchestrator.Schemas.Device
  alias NotificationOrchestrator.Schemas.Common

  tags ["Devices"]
  security [%{"bearer_auth" => []}]

  operation :register,
    summary: "Register device",
    description: "Register a device for push notifications. The device token is used to send push notifications to the device.",
    request_body: {"Device registration details", "application/json", Device.RegisterDeviceRequest},
    responses: [
      ok: {"Device registered successfully", "application/json", Device.RegisterDeviceResponse},
      bad_request: {"Invalid request", "application/json", Common.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

  def register(conn, %{"token" => token, "platform" => platform} = params) do
    user_id = conn.assigns[:current_user_id]
    device_id = UUID.uuid4()
    
    device = %{
      device_id: device_id,
      token: token,
      platform: platform,
      device_name: Map.get(params, "device_name", "Unknown"),
      registered_at: DateTime.utc_now()
    }

    Mongo.update_one(:notification_mongo, "user_devices",
      %{user_id: user_id},
      %{"$push" => %{devices: device}},
      upsert: true
    )

    json(conn, %{success: true, data: %{device_id: device_id}})
  end

  operation :unregister,
    summary: "Unregister device",
    description: "Unregister a device from push notifications. The device will no longer receive push notifications.",
    parameters: [
      device_id: [
        in: :path,
        type: :string,
        required: true,
        description: "The unique identifier of the device to unregister",
        example: "550e8400-e29b-41d4-a716-446655440000"
      ]
    ],
    responses: [
      ok: {"Device unregistered successfully", "application/json", Common.SuccessResponse},
      not_found: {"Device not found", "application/json", Common.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", Common.ErrorResponse}
    ]

  def unregister(conn, %{"device_id" => device_id}) do
    user_id = conn.assigns[:current_user_id]
    
    Mongo.update_one(:notification_mongo, "user_devices",
      %{user_id: user_id},
      %{"$pull" => %{devices: %{device_id: device_id}}}
    )

    json(conn, %{success: true})
  end
end
