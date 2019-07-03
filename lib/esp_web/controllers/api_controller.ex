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

  def cache_guild_exists(conn, params) do
    id = params["id"]
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/cache/guild/#{id}").body
    # lol
    case data do
      "{}" -> conn |> json(%{"exists" => false})
      _   -> conn |> json(%{"exists" => true})
    end
  end

  # Imports

  def import_levels(conn, params) do
    guild = params["id"]
    type = params["type"]

    key = conn |> get_req_header("authorization") |> hd

    {state, response} = key_owns_guild key, guild
    case state do
      :ok ->
        HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/levels/import/#{guild}/#{type}", Poison.encode!(%{}))
        conn |> json(%{})
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  # Config

  defp key_owns_guild(key, guild_id) do
    {valid, id} = ESP.Key.check_key_valid key
    if valid do
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

  def webhooks_fetch(conn, params) do
    guild = params["id"]
    key = conn |> get_req_header("authorization") |> hd
    {state, response} = key_owns_guild key, guild
    case state do
      :ok ->
        response = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/guild/#{guild}/webhooks", [], [recv_timeout: 20_000, timeout: 20_000]).body
        conn |> json(response)
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  def webhooks_fetch_one(conn, params) do
    guild = params["guild"]
    id = params["id"]
    key = conn |> get_req_header("authorization") |> hd
    {state, response} = key_owns_guild key, guild
    case state do
      :ok ->
        response = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/guild/#{guild}/webhooks/#{id}", [], [recv_timeout: 20_000, timeout: 20_000]).body
        conn |> json(response)
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  def webhooks_delete_one(conn, params) do
    guild = params["guild"]
    id = params["id"]
    key = conn |> get_req_header("authorization") |> hd
    {state, response} = key_owns_guild key, guild
    case state do
      :ok ->
        _response = HTTPoison.delete!(System.get_env("INTERNAL_API") <> "/data/guild/#{guild}/webhooks/#{id}", [], [recv_timeout: 20_000, timeout: 20_000]).body
        conn |> json(%{})
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  # Other guild data

  def guild_levels_fetch(conn, params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/guild/#{params["id"]}/levels", [], [recv_timeout: 60_000, timeout: 60_000]).body
    # doing |> json(data) json-encodes a json string giving wrong results
    # idk why this one is special but others aren't :I
    conn |> text(data)
  end

  def user_manages_guild(conn, params) do
    id = params["id"]
    key = conn |> get_req_header("authorization") |> hd
    {status, response} = key_owns_guild key, id
    case status do
      :ok ->
        conn |> json(%{"manages" => true})
      :error ->
        conn |> json(%{"manages" => false})
    end
  end

  # Accounts

  def account_get_profile(conn, params) do
    id = params["id"]
    res = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/#{id}/profile", [], [recv_timeout: 20_000, timeout: 20_000]).body
          |> Poison.decode!
    conn |> json(res)
  end

  def account_update_profile(conn, params) do
    key = conn |> get_req_header("authorization") |> hd
    {valid, id} = ESP.Key.check_key_valid key

    if valid do
      data = Map.merge %{}, params

      res = HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/account/update", Poison.encode!(data)).body
      conn |> json(res)
    else
      conn |> json(%{})
    end
  end

  def account_links_discord_id(conn, params) do
    id = params["id"]
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/links/discord/" <> id, [], [recv_timeout: 20_000, timeout: 20_000]).body
    conn |> text("\"" <> data <> "\"")
  end

  def account_get_posts(conn, params) do
    id = params["id"]
    res = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/#{id}/posts", [], [recv_timeout: 20_000, timeout: 20_000]).body
    conn |> text(res)
  end

  # Store

  def store_get_manifest(conn, _params) do
    res = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/store/manifest", [], [recv_timeout: 20_000, timeout: 20_000]).body
    conn |> text(res)
  end

  def store_checkout_start(conn, params) do
    data = %{
      "userId" => params["userId"],
      "sku"    => params["sku"],
    }
    res = HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/store/checkout/start", Poison.encode!(data)).body
    conn |> text(res)
  end

  def store_checkout_confirm(conn, params) do
    internal_data = %{
      "userId"    => params["userId"],
      "paymentId" => params["paymentId"],
      "payerId"   => params["PayerID"],
    }
    res = HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/store/checkout/confirm", Poison.encode!(internal_data)).body
    Logger.info "Got payment: #{inspect res, pretty: true}"
    data = %{
      "finished" => true,
      "mode"     => "store",
    }
    conn
    |> html("""
        <script>
        window.opener.postMessage(#{Poison.encode!(data)}, "*");
        self.close();
        </script>
        """)
  end

  # Heartbeat

  def heartbeat(conn, _params) do
    key = conn |> get_req_header("authorization") |> hd
    {valid, id} = ESP.Key.check_key_valid key
    if valid do
      conn |> json(%{"check" => id})
    else
      Logger.info "Got invalid key for id #{id}: #{key}"
      conn |> json(%{"check" => nil})
    end
  end

  # Metadata

  def get_plugins(conn, _params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/plugins/metadata", [], [recv_timeout: 20_000, timeout: 20_000]).body |> Poison.decode!
    conn |> json(data)
  end

  def get_commands(conn, _params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/commands/metadata", [], [recv_timeout: 20_000, timeout: 20_000]).body |> Poison.decode!
    conn |> json(data)
  end

  def backgrounds_packs(conn, _params) do
    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/backgrounds/packs").body |> Poison.decode!
    conn |> json(data)
  end

  # Telepathy

  def get_twitch_user_by_name(conn, params) do
    # Because ratelimits(tm), this lookup may take a while
    data = HTTPoison.get!(System.get_env("TELEPATHY_URL") <> "/api/v1/twitch/lookup/name/" <> params["name"],
              [], [timeout: 120_000, recv_timeout: 120_000]).body
            |> Poison.decode!
    conn |> json(data)
  end

  def get_twitch_user_by_id(conn, params) do
    # Because ratelimits(tm), this lookup may take a while
    data = HTTPoison.get!(System.get_env("TELEPATHY_URL") <> "/api/v1/twitch/lookup/id/" <> params["id"],
              [], [timeout: 120_000, recv_timeout: 120_000]).body
            |> Poison.decode!
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
