import Config

config :notification_orchestrator, namespace: NotificationOrchestrator

config :notification_orchestrator, NotificationOrchestrator.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: NotificationOrchestrator.ErrorJSON], layout: false],
  pubsub_server: NotificationOrchestrator.PubSub

config :notification_orchestrator, :mongodb,
  url: System.get_env("MONGODB_URI") || "mongodb://localhost:27017/quckchat_notifications",
  pool_size: 10

config :notification_orchestrator, :redis,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  database: 6

config :notification_orchestrator, :kafka,
  brokers: [System.get_env("KAFKA_BROKER") || "localhost:9092"],
  consumer_group: "notification-orchestrator-group"

config :notification_orchestrator, NotificationOrchestrator.Guardian,
  issuer: "quckchat",
  secret_key: System.get_env("JWT_SECRET") || "your-secret-key"

config :notification_orchestrator, :firebase,
  project_id: System.get_env("FIREBASE_PROJECT_ID"),
  service_account: System.get_env("FIREBASE_SERVICE_ACCOUNT")

config :notification_orchestrator, :apns,
  key_id: System.get_env("APNS_KEY_ID"),
  team_id: System.get_env("APNS_TEAM_ID"),
  key: System.get_env("APNS_KEY")

config :libcluster, topologies: [notification_cluster: [strategy: Cluster.Strategy.Gossip]]
config :logger, :console, format: "$time $metadata[$level] $message\n", metadata: [:request_id]
config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
