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

  # Heartbeat

  def heartbeat(conn, _params) do
    key = conn |> get_req_header("authorization") |> hd
    id = ESP.Key.reverse_key_lookup key
    conn |> json(%{"check" => id})
  end

  # Commands

  def get_commands(conn, _params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/commands").body |> Poison.decode!
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