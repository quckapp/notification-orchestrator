# =============================================================================
# LOCAL (Mock) Environment Configuration
# =============================================================================
# Use this profile for local development with Docker containers
# Run with: MIX_ENV=local mix phx.server
# =============================================================================

import Config

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4007],
  check_origin: false,
  debug_errors: true,
  code_reloader: false,
  secret_key_base: "local_dev_secret_key_base_notification_orchestrator_quckapp_32_chars"

# MongoDB - Local Docker
config :notification_orchestrator, :mongodb,
  url: "mongodb://localhost:27017/quckapp_notifications",
  pool_size: 5

# Redis - Local Docker
config :notification_orchestrator, :redis,
  host: "localhost",
  port: 6379,
  password: nil,
  database: 6

# Kafka - Local Docker
config :notification_orchestrator, :kafka,
  brokers: [{"localhost", 9092}],
  consumer_group: "notification-orchestrator-local"

# JWT - Same secret as auth-service local
config :notification_orchestrator, NotificationOrchestrator.Guardian,
  issuer: "quckapp-auth-local",
  secret_key: "bG9jYWwtZGV2LXNlY3JldC1rZXktZm9yLXRlc3Rpbmctb25seS0zMi1jaGFycw=="

# Firebase (FCM) - Local/Mock
config :notification_orchestrator, :firebase,
  project_id: "quckapp-local",
  service_account: nil,
  enabled: false

# APNS - Local/Mock (disabled for local development)
config :notification_orchestrator, :apns,
  key_id: nil,
  team_id: nil,
  key: nil,
  mode: :dev,
  enabled: false

# Pigeon FCM Configuration - Local
config :pigeon, :fcm,
  project_id: "quckapp-local",
  enabled: false

# Pigeon APNS Configuration - Local
config :pigeon, :apns,
  mode: :dev,
  enabled: false

# libcluster - Local (no clustering)
config :libcluster,
  topologies: []

# Services
config :notification_orchestrator, :services,
  auth_service_url: "http://localhost:8081",
  user_service_url: "http://localhost:8082"

# Logging - Verbose for local
config :logger, :console,
  format: "[$level] $message\n",
  level: :debug
