defmodule NotificationOrchestrator.DeviceController do
  use Phoenix.Controller, formats: [:json]

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

  def unregister(conn, %{"device_id" => device_id}) do
    user_id = conn.assigns[:current_user_id]
    
    Mongo.update_one(:notification_mongo, "user_devices",
      %{user_id: user_id},
      %{"$pull" => %{devices: %{device_id: device_id}}}
    )

    json(conn, %{success: true})
  end
end
