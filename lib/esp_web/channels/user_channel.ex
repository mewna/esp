defmodule ESPWeb.UserChannel do
  use Phoenix.Channel
  require Logger

  @msg "m"

  def join("esp:user-socket", _message, socket) do
    send self(), :after_join_base
    Logger.info "Got socket join"
    {:ok, assign(socket, :key, UUID.uuid4())}
  end

  def join("esp:user:" <> user_id, auth_message, socket) do
    unless is_nil auth_message do
      if Map.has_key?(auth_message, "key") do
        # verify key
        if auth_message["key"] == ESP.Key.get_key(user_id) do
          send self(), :after_join_user
          {:ok, assign(socket, :key, auth_message["key"])}
        else
          {:error, %{"auth_state" => "invalid"}}
        end
      else
        {:error, %{"auth_state" => "unknown"}}
      end
    else
      {:error, %{"auth_state" => "unknown"}}
    end
  end

  def join("esp:cache:user:" <> id, _message, socket) do
    {:ok, assign(socket, :id, id)}
  end

  def join("esp:dashboard:" <> id, _message, socket) do
    send self(), :after_join_dashboard
    {:ok, assign(socket, :id, id)}
  end

  def handle_info(:after_join_base, socket) do
    push_message socket, "HELLO", %{"key" => socket.assigns.key}
    {:noreply, socket}
  end

  def handle_info(:after_join_user, socket) do
    push_message socket, "HELLO", %{"auth_state" => "success"}
    {:noreply, socket}
  end

  def handle_info(:after_join_dashboard, socket) do
    {state, data} = socket.assigns.id |> ESP.Key.refresh_data 
    push_message socket, "DATA", %{"state" => state, "data" => data}
    {:noreply, socket}
  end

  defp push_message(socket, type, data) do
    push socket, @msg, message(type, data)
  end

  defp message(type, data) do
    %{
      "t" => type,
      "d" => data,
      "ts" => :erlang.system_time(:millisecond),
    }
  end
end