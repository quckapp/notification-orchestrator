import Config

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4004],
  check_origin: false, debug_errors: true,
  secret_key_base: "dev_secret_key_base_notification_orchestrator",
  watchers: []

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :plug_init_mode, :runtime
