defmodule NotificationOrchestrator.Router do
  use Phoenix.Router
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
    plug NotificationOrchestrator.Plugs.AuthPlug
  end

  pipeline :public do
    plug :accepts, ["json"]
  end

  scope "/api/v1/notifications", NotificationOrchestrator do
    pipe_through :api

    post "/", NotificationController, :send
    post "/bulk", NotificationController, :send_bulk
    get "/", NotificationController, :index
    get "/unread-count", NotificationController, :unread_count
    post "/mark-read", NotificationController, :mark_read
    post "/devices", DeviceController, :register
    delete "/devices/:device_id", DeviceController, :unregister
  end

  scope "/health", NotificationOrchestrator do
    pipe_through :public
    get "/", HealthController, :index
    get "/ready", HealthController, :ready
  end
end
