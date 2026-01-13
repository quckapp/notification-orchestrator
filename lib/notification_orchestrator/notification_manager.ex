defmodule NotificationOrchestrator.NotificationManager do
  use GenServer
  require Logger

  @notification_types [:push, :email, :sms, :in_app]
  @priorities [:high, :normal, :low]

  defstruct [:notification_id, :user_id, :type, :title, :body, :data, :priority, 
             :channels, :status, :sent_at, :read_at, :created_at]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def send_notification(user_id, type, title, body, opts \ []) when type in @notification_types do
    GenServer.call(__MODULE__, {:send, user_id, type, title, body, opts})
  end

  def send_bulk(user_ids, type, title, body, opts \ []) when type in @notification_types do
    GenServer.call(__MODULE__, {:send_bulk, user_ids, type, title, body, opts})
  end

  def get_notifications(user_id, opts \ []) do
    GenServer.call(__MODULE__, {:get_notifications, user_id, opts})
  end

  def mark_as_read(notification_ids, user_id) do
    GenServer.cast(__MODULE__, {:mark_read, notification_ids, user_id})
  end

  def get_unread_count(user_id) do
    GenServer.call(__MODULE__, {:unread_count, user_id})
  end

  @impl true
  def init(_state), do: {:ok, %{}}

  @impl true
  def handle_call({:send, user_id, type, title, body, opts}, _from, state) do
    notification_id = UUID.uuid4()
    priority = Keyword.get(opts, :priority, :normal)
    data = Keyword.get(opts, :data, %{})
    channels = Keyword.get(opts, :channels, [:push, :in_app])

    notification = %__MODULE__{
      notification_id: notification_id,
      user_id: user_id,
      type: type,
      title: title,
      body: body,
      data: data,
      priority: priority,
      channels: channels,
      status: :pending,
      created_at: DateTime.utc_now()
    }

    # Store notification
    store_notification_mongo(notification)

    # Get user devices and preferences
    devices = get_user_devices(user_id)
    
    # Send to appropriate channels
    results = Enum.map(channels, fn channel ->
      send_to_channel(channel, notification, devices)
    end)

    updated_notification = %{notification | status: :sent, sent_at: DateTime.utc_now()}
    update_notification_mongo(updated_notification)

    :telemetry.execute([:notification, :sent], %{count: 1}, %{type: type})
    Logger.info("Notification #{notification_id} sent to user #{user_id}")

    {:reply, {:ok, updated_notification}, state}
  end

  @impl true
  def handle_call({:send_bulk, user_ids, type, title, body, opts}, _from, state) do
    results = Enum.map(user_ids, fn user_id ->
      send_notification(user_id, type, title, body, opts)
    end)
    
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    {:reply, {:ok, %{sent: success_count, total: length(user_ids)}}, state}
  end

  @impl true
  def handle_call({:get_notifications, user_id, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 50)
    unread_only = Keyword.get(opts, :unread_only, false)
    
    query = %{user_id: user_id}
    query = if unread_only, do: Map.put(query, :read_at, nil), else: query
    
    notifications = Mongo.find(:notification_mongo, "notifications", query,
      sort: %{created_at: -1}, limit: limit
    ) |> Enum.to_list()
    
    {:reply, {:ok, notifications}, state}
  end

  @impl true
  def handle_call({:unread_count, user_id}, _from, state) do
    count = Mongo.count_documents!(:notification_mongo, "notifications", 
      %{user_id: user_id, read_at: nil}
    )
    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_cast({:mark_read, notification_ids, user_id}, state) do
    Enum.each(notification_ids, fn id ->
      Mongo.update_one(:notification_mongo, "notifications",
        %{notification_id: id, user_id: user_id},
        %{"$set" => %{read_at: DateTime.utc_now()}}
      )
    end)
    {:noreply, state}
  end

  defp store_notification_mongo(notification) do
    doc = Map.from_struct(notification) |> Map.put(:_id, notification.notification_id)
    Mongo.insert_one(:notification_mongo, "notifications", doc)
  end

  defp update_notification_mongo(notification) do
    doc = Map.from_struct(notification)
    Mongo.update_one(:notification_mongo, "notifications", 
      %{notification_id: notification.notification_id}, %{"$set" => doc})
  end

  defp get_user_devices(user_id) do
    case Mongo.find_one(:notification_mongo, "user_devices", %{user_id: user_id}) do
      nil -> []
      doc -> Map.get(doc, "devices", [])
    end
  end

  defp send_to_channel(:push, notification, devices) do
    Enum.each(devices, fn device ->
      case device["platform"] do
        "android" -> NotificationOrchestrator.Providers.Firebase.send(device["token"], notification)
        "ios" -> NotificationOrchestrator.Providers.APNs.send(device["token"], notification)
        "web" -> NotificationOrchestrator.Providers.Firebase.send(device["token"], notification)
        _ -> :ok
      end
    end)
    :ok
  end

  defp send_to_channel(:email, notification, _devices) do
    NotificationOrchestrator.Providers.Email.send(notification.user_id, notification)
  end

  defp send_to_channel(:in_app, notification, _devices) do
    Phoenix.PubSub.broadcast(NotificationOrchestrator.PubSub, 
      "user:#{notification.user_id}", {:new_notification, notification})
    :ok
  end

  defp send_to_channel(_, _notification, _devices), do: :ok
end
