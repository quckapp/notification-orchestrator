defmodule NotificationOrchestrator.Endpoint do
  use Phoenix.Endpoint, otp_app: :notification_orchestrator

  socket "/socket", NotificationOrchestrator.UserSocket, websocket: [timeout: 45_000], longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # JSON-formatted request logging with Logster
  plug Logster.Plugs.Logger, log: :info, formatter: Logster.JSONFormatter

  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Jason
  plug Plug.MethodOverride
  plug Plug.Head
  plug CORSPlug, origin: ["*"]
  plug NotificationOrchestrator.Router
end
