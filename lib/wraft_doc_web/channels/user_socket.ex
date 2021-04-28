defmodule WraftDocWeb.UserSocket do
  use Phoenix.Socket
  alias WraftDocWeb.Guardian

  ## Channels
  # channel("notification:*", WraftDocWeb.NotificationChannel)
  # # channel "room:*", WraftDocWeb.RoomChannel
  # transport(:websocket, Phoenix.Transports.WebSocket)

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  # def connect(_params, socket) do
  #   {:ok, socket}
  # end

  def connect(%{"token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, user, _claims} ->
        {:ok, assign(socket, :current_user, user)}

      _ ->
        :error
    end
  end

  def connect(_params, _socket), do: :error

  # def id(socket), do: socket.assigns[:current_user].id |> to_string()

  def id(socket) do
    socket = socket.assigns[:current_user].id
    to_string(socket)
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     WraftDocWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
end
