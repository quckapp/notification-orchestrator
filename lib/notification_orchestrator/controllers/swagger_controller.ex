defmodule NotificationOrchestrator.SwaggerController do
  @moduledoc """
  Controller for serving Swagger UI and OpenAPI specification.
  """

  use Phoenix.Controller, formats: [:json, :html]

  alias OpenApiSpex.OpenApi

  @doc """
  Renders the Swagger UI HTML page.
  """
  def index(conn, _params) do
    html(conn, swagger_ui_html())
  end

  @doc """
  Returns the OpenAPI specification as JSON.
  """
  def spec(conn, _params) do
    spec = NotificationOrchestrator.ApiSpec.spec()
    json(conn, OpenApi.to_map(spec))
  end

  defp swagger_ui_html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Notification Orchestrator API - Swagger UI</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
      <style>
        html {
          box-sizing: border-box;
          overflow: -moz-scrollbars-vertical;
          overflow-y: scroll;
        }
        *,
        *:before,
        *:after {
          box-sizing: inherit;
        }
        body {
          margin: 0;
          background: #fafafa;
        }
        .swagger-ui .topbar {
          background-color: #1a1a2e;
        }
        .swagger-ui .topbar .download-url-wrapper .select-label {
          color: #fff;
        }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js" charset="UTF-8"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js" charset="UTF-8"></script>
      <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: "/swagger/spec",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout",
            persistAuthorization: true,
            displayRequestDuration: true,
            filter: true,
            showExtensions: true,
            showCommonExtensions: true,
            tryItOutEnabled: true
          });
          window.ui = ui;
        };
      </script>
    </body>
    </html>
    """
  end
end
