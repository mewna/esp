defmodule ESPWeb.ApiController do
  use ESPWeb, :controller
  require Logger

  # Cache

  def cache(conn, params) do
    cond do
      params["type"] in ["user", "guild", "role", "channel"] ->
        type = params["type"]
        id = params["id"]
        data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/cache/#{type}/#{id}").body |> Poison.decode!
        data = data |> Map.put("username", data["name"])
        conn |> json(data)
      false ->
        conn |> json(%{"error" => "bad cache type"})
    end
  end

  def cache_guild_channels(conn, params) do
    id = params["id"]
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/cache/guild/#{id}/channels").body |> Poison.decode!
    conn |> json(data)
  end

  def cache_guild_roles(conn, params) do
    id = params["id"]
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/cache/guild/#{id}/roles").body |> Poison.decode!
    conn |> json(data)
  end

  # Config

  defp key_owns_guild(key, guild_id) do
    {valid, id} = ESP.Key.parse_key key
    if valid do
      # Get the user
      #user = ESP.Key.get_user id
      # Ensure the key is valid for this guild
      guilds = ESP.Key.get_guilds id
      if guilds |> Enum.any?(fn(x) -> x["id"] == guild_id end) do
        # We're good
        {:ok, "ok"}
      else
        {:error, "unauthorized"}
      end
    else
      {:error, "invalid key"}
    end
  end

  def config_guild_fetch(conn, params) do
    guild = params["id"]
    type = params["type"]
    key = conn |> get_req_header("authorization") |> hd

    {state, response} = key_owns_guild key, guild
    case state do
      :ok ->
        data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/guild/#{guild}/config/#{type}").body
        conn |> json(data)
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  def config_guild_update(conn, params) do
    guild = params["id"]
    type = params["type"]
    data = Map.merge(%{}, params)
    {_, data} = Map.pop data, "id"
    {_, data} = Map.pop data, "type"
    key = conn |> get_req_header("authorization") |> hd
    {state, response} = key_owns_guild key, guild
    case state do
      :ok ->
        response = HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/guild/#{guild}/config/#{type}", Poison.encode!(data)).body
        conn |> json(response)
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  # Heartbeat

  def heartbeat(conn, _params) do
    key = conn |> get_req_header("authorization") |> hd
    {valid, id} = ESP.Key.parse_key key
    if valid do
      conn |> json(%{"check" => id})
    else
      conn |> json(%{"check" => nil})
    end
  end

  # Metadata

  def get_plugins(conn, _params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/plugins/metadata").body |> Poison.decode!
    conn |> json(data)
  end

  def get_commands(conn, _params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/commands/metadata").body |> Poison.decode!
    conn |> json(data)
  end

  # Fucking CORS man

  def options(conn, _params) do
    conn |> json(%{})
  end

  # Auth

  def logout(conn, params) do
    key = params["key"]
    ESP.Key.clear_auth_by_key key
    conn |> json(%{})
  end
end