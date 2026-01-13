import Config

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4005],
  secret_key_base: "test_secret",
  server: false

config :logger, level: :warning
