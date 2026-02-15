import Config

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4004],
  check_origin: false, debug_errors: true,
  secret_key_base: "dev_secret_key_base_notification_orchestrator",
  watchers: []

# MongoDB configuration for development
config :notification_orchestrator, :mongodb,
  url: "mongodb://localhost:27017/quckapp_notifications_dev",
  pool_size: 5

# Redis configuration for development
config :notification_orchestrator, :redis,
  host: "localhost",
  port: 6379,
  database: 6

# Kafka configuration for development (disabled by default)
config :notification_orchestrator, :kafka,
  enabled: false,
  brokers: [{~c"localhost", 9092}],
  consumer_group: "notification-orchestrator-group-dev"

# Guardian JWT configuration for development
config :notification_orchestrator, NotificationOrchestrator.Guardian,
  issuer: "notification_orchestrator",
  secret_key: "dev_jwt_secret_for_notification_orchestrator"

# libcluster topology for development (no clustering)
config :libcluster, topologies: []

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :plug_init_mode, :runtime
