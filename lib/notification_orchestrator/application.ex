defmodule NotificationOrchestrator.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NotificationOrchestrator.Telemetry,
      {Phoenix.PubSub, name: NotificationOrchestrator.PubSub},
      {Mongo, [
        name: :notification_mongo,
        url: Application.get_env(:notification_orchestrator, :mongodb)[:url],
        pool_size: Application.get_env(:notification_orchestrator, :mongodb)[:pool_size] || 10
      ]},
      {Redix, [
        host: Application.get_env(:notification_orchestrator, :redis)[:host],
        port: Application.get_env(:notification_orchestrator, :redis)[:port],
        database: Application.get_env(:notification_orchestrator, :redis)[:database] || 6,
        name: :notification_redis
      ]},
      {Finch, name: NotificationOrchestrator.Finch},
      NotificationOrchestrator.NotificationManager,
      NotificationOrchestrator.Providers.Firebase,
      NotificationOrchestrator.Providers.APNs,
      NotificationOrchestrator.Providers.Email,
      NotificationOrchestrator.Kafka.Consumer,
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies), [name: NotificationOrchestrator.ClusterSupervisor]]},
      NotificationOrchestrator.Endpoint
    ]

    opts = [strategy: :one_for_one, name: NotificationOrchestrator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NotificationOrchestrator.Endpoint.config_change(changed, removed)
    :ok
  end
end
