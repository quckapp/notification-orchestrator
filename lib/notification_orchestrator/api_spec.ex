defmodule NotificationOrchestrator.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Notification Orchestrator API.
  """

  alias OpenApiSpex.{Info, OpenApi, Paths, Server, Components, SecurityScheme}
  alias NotificationOrchestrator.{Endpoint, Router}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Notification Orchestrator API",
        description: "Push notification and device management API",
        version: "1.0.0"
      },
      servers: [
        %Server{url: "/", description: "Current server"}
      ],
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "bearer_auth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description: "JWT Bearer token authentication"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
