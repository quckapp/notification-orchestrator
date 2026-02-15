defmodule NotificationOrchestrator.Schemas.Common do
  @moduledoc """
  Common schemas used across the Notification Orchestrator API.
  """

  alias OpenApiSpex.Schema

  defmodule SuccessResponse do
    @moduledoc "Generic success response"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SuccessResponse",
      description: "A generic success response",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful", example: true}
      },
      required: [:success],
      example: %{
        success: true
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc "Generic error response"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "A generic error response",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Indicates if the operation was successful", example: false},
        error: %Schema{type: :string, description: "Error message describing what went wrong"}
      },
      required: [:success, :error],
      example: %{
        success: false,
        error: "Invalid request parameters"
      }
    })
  end

  defmodule HealthResponse do
    @moduledoc "Health check response"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthResponse",
      description: "Health check response",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Service health status", example: "healthy"},
        service: %Schema{type: :string, description: "Service name", example: "notification-orchestrator"},
        timestamp: %Schema{type: :string, format: :"date-time", description: "Current timestamp"}
      },
      required: [:status, :service],
      example: %{
        status: "healthy",
        service: "notification-orchestrator",
        timestamp: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule ReadinessResponse do
    @moduledoc "Readiness check response"
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ReadinessResponse",
      description: "Readiness check response",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Service readiness status", example: "ready"},
        checks: %Schema{
          type: :object,
          description: "Individual component checks",
          additionalProperties: %Schema{type: :string}
        }
      },
      required: [:status],
      example: %{
        status: "ready",
        checks: %{
          mongodb: "connected",
          redis: "connected",
          kafka: "connected"
        }
      }
    })
  end
end
