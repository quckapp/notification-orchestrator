# =============================================================================
# STAGING Environment Configuration
# =============================================================================
# Use this profile for staging environment
# Run with: MIX_ENV=staging mix phx.server
# =============================================================================

import Config

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4007")],
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 443, scheme: "https"],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true

# MongoDB - Staging (higher pool size)
config :notification_orchestrator, :mongodb,
  url: System.get_env("MONGODB_URI"),
  pool_size: String.to_integer(System.get_env("MONGODB_POOL_SIZE") || "25")

# Redis - Staging (higher pool size)
config :notification_orchestrator, :redis,
  host: System.get_env("REDIS_HOST"),
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  password: System.get_env("REDIS_PASSWORD"),
  database: String.to_integer(System.get_env("REDIS_DATABASE") || "6"),
  pool_size: 16

# Kafka - Staging
config :notification_orchestrator, :kafka,
  brokers: [System.get_env("KAFKA_BROKER") || "localhost:9092"],
  consumer_group: "notification-orchestrator-staging"

# JWT
config :notification_orchestrator, NotificationOrchestrator.Guardian,
  issuer: "quckapp-auth",
  secret_key: System.get_env("JWT_SECRET")

# Firebase (FCM) - Staging
config :notification_orchestrator, :firebase,
  project_id: System.get_env("FIREBASE_PROJECT_ID"),
  service_account: System.get_env("FIREBASE_SERVICE_ACCOUNT"),
  enabled: true

# APNS - Staging (production mode)
config :notification_orchestrator, :apns,
  key_id: System.get_env("APNS_KEY_ID"),
  team_id: System.get_env("APNS_TEAM_ID"),
  key: System.get_env("APNS_KEY"),
  mode: :prod,
  enabled: true

# Pigeon FCM Configuration - Staging
config :pigeon, :fcm,
  project_id: System.get_env("FIREBASE_PROJECT_ID"),
  service_account_json: System.get_env("FIREBASE_SERVICE_ACCOUNT")

# Pigeon APNS Configuration - Staging
config :pigeon, :apns,
  key_id: System.get_env("APNS_KEY_ID"),
  team_id: System.get_env("APNS_TEAM_ID"),
  key: System.get_env("APNS_KEY"),
  mode: :prod

# libcluster - Staging (Kubernetes DNS strategy)
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
  auth_service_url: System.get_env("AUTH_SERVICE_URL"),
  user_service_url: System.get_env("USER_SERVICE_URL")

# Logging - Info level for staging
config :logger, level: :info
