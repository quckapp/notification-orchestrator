defmodule NotificationOrchestrator.UserSocket do
  use Phoenix.Socket
  require Logger

  channel "notifications:*", NotificationOrchestrator.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case NotificationOrchestrator.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        user_id = claims["sub"]
        {:ok, assign(socket, :user_id, user_id)}
      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
