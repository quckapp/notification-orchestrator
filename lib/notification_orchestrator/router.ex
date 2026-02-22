defmodule NotificationOrchestrator.Router do
  use Phoenix.Router
  import Phoenix.Controller

  alias OpenApiSpex.Operation

  pipeline :api do
    plug :accepts, ["json"]
    plug NotificationOrchestrator.Plugs.AuthPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: NotificationOrchestrator.ApiSpec
  end

  pipeline :public do
    plug :accepts, ["json"]
  end

  pipeline :swagger do
    plug :accepts, ["json", "html"]
  end

  # Swagger UI routes
  scope "/swagger" do
    pipe_through :swagger
    get "/", NotificationOrchestrator.SwaggerController, :index
    get "/spec", NotificationOrchestrator.SwaggerController, :spec
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
