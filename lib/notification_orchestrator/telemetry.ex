defmodule NotificationOrchestrator.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [{Telemetry.Metrics.ConsoleReporter, metrics: metrics()}]
    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      counter("notification.sent.count"),
      counter("notification.delivered.count"),
      counter("notification.failed.count"),
      summary("notification.send.duration", unit: {:native, :millisecond}),
      counter("notification.firebase.sent.count"),
      counter("notification.apns.sent.count"),
      counter("notification.email.sent.count")
    ]
  end
end
