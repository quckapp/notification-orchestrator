# =============================================================================
# LIVE Environment Configuration
# =============================================================================
# Use this profile for live environment (same as production with stricter settings)
# Run with: MIX_ENV=live mix phx.server
# =============================================================================

import Config

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4007")],
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 443, scheme: "https"],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || raise("SECRET_KEY_BASE missing"),
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"

# MongoDB - Live (highest pool size)
config :notification_orchestrator, :mongodb,
  url: System.get_env("MONGODB_URI") || raise("MONGODB_URI missing"),
  pool_size: String.to_integer(System.get_env("MONGODB_POOL_SIZE") || "100"),
  timeout: 15_000,
  connect_timeout: 10_000

# Redis - Live (highest pool size)
config :notification_orchestrator, :redis,
  host: System.get_env("REDIS_HOST") || raise("REDIS_HOST missing"),
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  password: System.get_env("REDIS_PASSWORD"),
  database: String.to_integer(System.get_env("REDIS_DATABASE") || "6"),
  pool_size: 64,
  ssl: System.get_env("REDIS_SSL") == "true"

# Kafka - Live
config :notification_orchestrator, :kafka,
  brokers: String.split(System.get_env("KAFKA_BROKERS") || "localhost:9092", ","),
  consumer_group: "notification-orchestrator-live",
  ssl: System.get_env("KAFKA_SSL") == "true"

# JWT
config :notification_orchestrator, NotificationOrchestrator.Guardian,
  issuer: "quckapp-auth",
  secret_key: System.get_env("JWT_SECRET") || raise("JWT_SECRET missing")

# Firebase (FCM) - Live
config :notification_orchestrator, :firebase,
  project_id: System.get_env("FIREBASE_PROJECT_ID") || raise("FIREBASE_PROJECT_ID missing"),
  service_account: System.get_env("FIREBASE_SERVICE_ACCOUNT") || raise("FIREBASE_SERVICE_ACCOUNT missing"),
  enabled: true

# APNS - Live
config :notification_orchestrator, :apns,
  key_id: System.get_env("APNS_KEY_ID") || raise("APNS_KEY_ID missing"),
  team_id: System.get_env("APNS_TEAM_ID") || raise("APNS_TEAM_ID missing"),
  key: System.get_env("APNS_KEY") || raise("APNS_KEY missing"),
  mode: :prod,
  enabled: true

# Pigeon FCM Configuration - Live
config :pigeon, :fcm,
  project_id: System.get_env("FIREBASE_PROJECT_ID"),
  service_account_json: System.get_env("FIREBASE_SERVICE_ACCOUNT")

# Pigeon APNS Configuration - Live
config :pigeon, :apns,
  key_id: System.get_env("APNS_KEY_ID"),
  team_id: System.get_env("APNS_TEAM_ID"),
  key: System.get_env("APNS_KEY"),
  mode: :prod

# libcluster - Live (Kubernetes DNS strategy)
config :libcluster,
  topologies: [
    notification_cluster: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: System.get_env("CLUSTER_SERVICE_NAME") || "notification-orchestrator-headless",
        application_name: "notification_orchestrator",
        polling_interval: 5_000
      ]
    ]
  ]

# Services
config :notification_orchestrator, :services,
  auth_service_url: System.get_env("AUTH_SERVICE_URL") || raise("AUTH_SERVICE_URL missing"),
  user_service_url: System.get_env("USER_SERVICE_URL") || raise("USER_SERVICE_URL missing")

# Logging - Error level only for live
config :logger, level: :error
