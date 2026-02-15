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

  # ---------------------------------------------------------------------------
  # Redis Configuration
  # ---------------------------------------------------------------------------
  redis_url = System.get_env("REDIS_URL")

  if redis_url do
    # Parse Redis URL if provided (redis://host:port/db)
    uri = URI.parse(redis_url)
    redis_host = uri.host || "localhost"
    redis_port = uri.port || 6379
    redis_database =
      case uri.path do
        "/" <> db -> String.to_integer(db)
        _ -> 6
      end

    config :notification_orchestrator, :redis,
      host: redis_host,
      port: redis_port,
      database: redis_database
  else
    config :notification_orchestrator, :redis,
      host: System.get_env("REDIS_HOST") || "localhost",
      port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
      database: String.to_integer(System.get_env("REDIS_DATABASE") || "6")
  end

  # ---------------------------------------------------------------------------
  # Kafka Configuration
  # ---------------------------------------------------------------------------
  kafka_enabled = System.get_env("KAFKA_ENABLED", "false") == "true"
  kafka_brokers_string = System.get_env("KAFKA_BROKERS") || System.get_env("KAFKA_BROKER") || "localhost:9092"

  kafka_brokers =
    kafka_brokers_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn broker ->
      case String.split(broker, ":") do
        [host, port] -> {String.to_charlist(host), String.to_integer(port)}
        [host] -> {String.to_charlist(host), 9092}
      end
    end)

  config :notification_orchestrator, :kafka,
    enabled: kafka_enabled,
    brokers: kafka_brokers,
    consumer_group: System.get_env("KAFKA_CONSUMER_GROUP") || "notification-orchestrator-group"

  # ---------------------------------------------------------------------------
  # Guardian (JWT) Configuration
  # ---------------------------------------------------------------------------
  jwt_secret =
    System.get_env("JWT_SECRET") ||
      raise """
      environment variable JWT_SECRET is missing.
      This is required for JWT token verification.
      """

  config :notification_orchestrator, NotificationOrchestrator.Guardian,
    issuer: "quckapp",
    secret_key: jwt_secret

  # ---------------------------------------------------------------------------
  # Auth Service Configuration
  # ---------------------------------------------------------------------------
  auth_service_url = System.get_env("AUTH_SERVICE_URL") || "http://localhost:8081"

  config :notification_orchestrator, :auth_service,
    url: auth_service_url

  # ---------------------------------------------------------------------------
  # Firebase (FCM) Configuration
  # ---------------------------------------------------------------------------
  firebase_credentials = System.get_env("FIREBASE_CREDENTIALS")
  firebase_project_id = System.get_env("FIREBASE_PROJECT_ID")
  firebase_service_account = System.get_env("FIREBASE_SERVICE_ACCOUNT")

  if firebase_credentials || firebase_project_id || firebase_service_account do
    config :notification_orchestrator, :firebase,
      credentials: firebase_credentials,
      project_id: firebase_project_id,
      service_account: firebase_service_account
  end

  # ---------------------------------------------------------------------------
  # Apple Push Notification Service (APNs) Configuration
  # ---------------------------------------------------------------------------
  apns_key = System.get_env("APNS_KEY")
  apns_key_id = System.get_env("APNS_KEY_ID")
  apns_team_id = System.get_env("APNS_TEAM_ID")

  if apns_key && apns_key_id && apns_team_id do
    config :notification_orchestrator, :apns,
      key: apns_key,
      key_id: apns_key_id,
      team_id: apns_team_id,
      mode: System.get_env("APNS_MODE") || "production"
  end

  # ---------------------------------------------------------------------------
  # Clustering Configuration
  # ---------------------------------------------------------------------------
  release_distribution = System.get_env("RELEASE_DISTRIBUTION") || "none"

  if release_distribution == "name" do
    # Distributed Erlang clustering
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
  else
    # No clustering in standalone mode
    config :libcluster, topologies: []
  end

  # ---------------------------------------------------------------------------
  # Oban (Background Jobs) Configuration
  # ---------------------------------------------------------------------------
  config :notification_orchestrator, Oban,
    repo: NotificationOrchestrator.Repo,
    plugins: [
      Oban.Plugins.Pruner,
      {Oban.Plugins.Cron, crontab: []}
    ],
    queues: [
      default: 10,
      notifications: 20,
      push: 30,
      email: 10
    ]

  # ---------------------------------------------------------------------------
  # Logger Configuration
  # ---------------------------------------------------------------------------
  log_level =
    case System.get_env("LOG_LEVEL") do
      "debug" -> :debug
      "info" -> :info
      "warning" -> :warning
      "warn" -> :warning
      "error" -> :error
      _ -> :info
    end

  config :logger, level: log_level

  config :logger, :console,
    format: "$time $metadata[$level] $message\n",
    metadata: [:request_id, :trace_id, :span_id]
end
