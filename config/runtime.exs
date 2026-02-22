import Config

# =============================================================================
# Runtime Configuration for Docker Environment
# =============================================================================
# This file is executed at runtime (not compile time) and reads environment
# variables for configuration. This allows the same release to be deployed
# to different environments with different configurations.
# =============================================================================

if config_env() == :prod do
  # ---------------------------------------------------------------------------
  # Endpoint Configuration
  # ---------------------------------------------------------------------------
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4004")

  config :notification_orchestrator, NotificationOrchestrator.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # ---------------------------------------------------------------------------
  # MongoDB Configuration
  # ---------------------------------------------------------------------------
  mongodb_url =
    System.get_env("MONGODB_URL") ||
      System.get_env("MONGODB_URI") ||
      raise """
      environment variable MONGODB_URL is missing.
      Example: mongodb://localhost:27017/quckapp_notifications
      """

  mongodb_pool_size = String.to_integer(System.get_env("MONGODB_POOL_SIZE") || "20")

  config :notification_orchestrator, :mongodb,
    url: mongodb_url,
    pool_size: mongodb_pool_size

  config :notification_orchestrator, :redis,
    host: System.get_env("REDIS_HOST") || "localhost",
    port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
    password: System.get_env("REDIS_PASSWORD"),
    database: 6

  config :notification_orchestrator, :kafka,
    brokers: String.split(System.get_env("KAFKA_BROKERS") || "localhost:9092", ","),
    consumer_group: "notification-orchestrator-group"

  config :notification_orchestrator, :firebase,
    project_id: System.get_env("FIREBASE_PROJECT_ID"),
    service_account: System.get_env("FIREBASE_SERVICE_ACCOUNT")
end
