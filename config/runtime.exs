import Config

if config_env() == :prod do
  config :notification_orchestrator, NotificationOrchestrator.Endpoint,
    url: [host: System.get_env("PHX_HOST") || "localhost", port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4004")],
    secret_key_base: System.get_env("SECRET_KEY_BASE") || raise("SECRET_KEY_BASE missing")

  config :notification_orchestrator, :mongodb,
    url: System.get_env("MONGODB_URI") || raise("MONGODB_URI missing"),
    pool_size: String.to_integer(System.get_env("MONGODB_POOL_SIZE") || "20")

  config :notification_orchestrator, :firebase,
    project_id: System.get_env("FIREBASE_PROJECT_ID"),
    service_account: System.get_env("FIREBASE_SERVICE_ACCOUNT")
end
