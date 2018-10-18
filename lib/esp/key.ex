# TODO: This does not allow for multiple sessions at once - fix!
defmodule ESP.Key do
  alias Lace.Redis
  require Logger
  use EntropyString, charset: :charset64, risk: 1.0e12

  @key_store          "esp:store:keys"
  @user_store         "esp:store:users"
  @token_store        "esp:store:discord:tokens"
  @guild_store        "esp:store:discord:guilds"

  @base_url   "https://discordapp.com/api"
  @oauth_url  @base_url <> "/oauth2"
  @token_url  @oauth_url <> "/token"
  @revoke_url @token_url <> "/revoke"
  @user_url   @base_url <> "/users/@me"
  @guilds_url @user_url <> "/guilds"

  ########
  # KEYS #
  ########

  defp keygen(id) when is_binary(id) do
    encoded_id = id |> Base.encode16

    time = :os.system_time(:millisecond) |> Integer.to_string
    encoded_time = time |> Base.encode16

    session_id = ESP.Key.random()
    encoded_session_id = session_id |> Base.encode16

    # what is security :S
    hmac = :crypto.hmac(:sha512, System.get_env("SIGNING_KEY"), "#{id}:#{time}:#{session_id}") |> Base.encode16
    # Why am I not just encoding JSON here?
    # Yeah idk either :V
    "esp." <> encoded_id <> "." <> encoded_time <> "." <> encoded_session_id <> "." <> hmac
  end

  def get_new_key(id) when is_binary(id) do
    key = keygen id
    session_id = get_session_id key
    Redis.q ["HSET", @key_store <> ":" <> id, session_id, key]
    Logger.info "Generated new key for #{id}"
    key
  end

  def clear_auth_by_key(nil) do
    # NOOP
  end
  def clear_auth_by_key(key) when is_binary(key) do
    session_id = get_session_id key
    user_id = get_user_id key
    Logger.info "Clearing #{user_id} session key #{session_id}"
    Redis.q ["HDEL", @key_store <> ":" <> user_id, session_id]
  end

  def parse_key(key) when is_binary(key) do
    [_esp, id, time, session_id, hmac] = key |> String.split("\.", parts: 5)
    [id, time, session_id, hmac]
  end

  def get_session_id(key) when is_binary(key) do
    [_, _, session_id, _] = parse_key key
    session_id |> Base.decode16!
  end
  def get_user_id(key) when is_binary(key) do
    [id, _, _, _] = parse_key key
    id |> Base.decode16!
  end

  def check_key_valid(key) when is_binary(key) do
    # TODO: Really there should just be a regex match or something to ensure that the token's formatting is valid...
    if key == "null" do
      # We just pass the token directly from whatever's in the auth. header, so
      # the client may actually send "null" and nothing else
      {false, nil}
    else
      [id, time, session_id, hmac] = parse_key key
      {_, id} = Base.decode16 id
      {_, time} = Base.decode16 time
      {_, session_id} = Base.decode16 session_id

      calculated_hmac = :crypto.hmac(:sha512, System.get_env("SIGNING_KEY"), "#{id}:#{time}:#{session_id}") |> Base.encode16
      # We don't use == here (or a simple byte-by-byte equality check) to avoid timing attacks - we
      # want this to be constant time. I don't remember how == is implemented in Erlang / Elixir,
      # so this is just for my sanity.
      valid = SecureCompare.compare calculated_hmac, hmac
      {:ok, stored} = Redis.q ["HGET", @key_store <> ":" <> id, session_id]
      if stored == key do
        {valid, id}
      else
        {false, id}
      end
    end
  end

  ################
  # OAUTH TOKENS #
  ################

  def set_token(id, data) when is_binary(id) do
    Redis.q ["HSET", @token_store, id, Poison.encode!(data)]
  end

  # %Ueberauth.Auth.Credentials{
  #   expires: true,
  #   expires_at: 1525386443,
  #   other: %{},
  #   refresh_token: "refresh 28974365827364",
  #   scopes: ["scopes"],
  #   secret: nil,
  #   token: "token 9028374982364",
  #   token_type: nil
  # }
  def get_token(id) when is_binary(id) do
    {:ok, token} = Redis.q ["HGET", @token_store, id]
    case token do
      :undefined -> nil
      _ -> Poison.decode!(token, as: %Ueberauth.Auth.Credentials{})
    end
  end

  ################
  # REFRESH DATA #
  ################

  def refresh_token(id) when is_binary(id) do
    token = get_token id
    if(token) do
      now = :os.system_time :second
      if token.expires_at < now do
        data = HTTPoison.post!(@token_url, URI.encode_query(%{
          "client_id" => System.get_env("DISCORD_CLIENT_ID"),
          "client_secret" => System.get_env("DISCORD_CLIENT_SECRET"),
          "grant_type" => "refresh_token",
          "refresh_token" => token.refresh_token,
          "redirect_uri" => System.get_env("DOMAIN") <> "/auth/discord/callback",
          "scope" => "identify guilds email connections",
        }), [{"Content-Type", "application/x-www-form-urlencoded"}]).body

        tmp = Poison.decode!(data)
        res = %Ueberauth.Auth.Credentials{
          expires: nil,
          expires_at: :os.system_time(:second) + tmp["expires_in"],
          other: [],
          refresh_token: tmp["refresh_token"],
          scopes: String.split(tmp["scope"]),
          secret: nil,
          token: tmp["access_token"],
          token_type: tmp["token_type"],
        }
        set_token id, res
        Logger.info "== Refreshed token for #{id}"
        res
      else
        Logger.info "== Not refreshing token for #{id} - expires #{token.expires_at}, now #{now}, check #{token.expires_at < now}"
        token
      end
    else
      Logger.info "== Not refreshing token for #{id} - no token!"
      nil
    end
  end

  def refresh_data(id) when is_binary(id) do
    token = get_token id
    unless is_nil token do
      token = refresh_token id
      {status, user} = get_user_from_api id, token
      {_, guilds} = get_guilds_from_api id, token
      case status do
        :ok -> {:ok, %{"user" => user["user"], "guilds" => guilds["guilds"]}}
        :error -> {:error, :invalid_token}
      end
    else
      {:error, :no_token}
    end
  end

  defp get_user_from_api(id, token) do
    case HTTPoison.get(@user_url, [{"Authorization", "Bearer #{token.token}"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        user_data = Poison.decode! body
        set_user id, user_data
        {:ok, %{"user" => user_data}}
      {:ok, %HTTPoison.Response{status_code: 429, body: body}} ->
        res = Poison.decode! body
        retry = res["retry_after"] + 250
        Logger.warn  "Ratelimited on #{id} user, retry in #{retry}"
        Process.sleep retry # Wait a bit extra to be safe

        user_res = HTTPoison.get! @user_url, [{"Authorization", "Bearer #{token.token}"}]
        user_data = Poison.decode! user_res.body
        set_user id, user_data
        {:ok, %{"user" => user_data}}
      {status, data} ->
        Logger.warn "Got response: {#{inspect status, pretty: true}, #{inspect data, pretty: true}}"
        {:error, :invalid_token}
    end
  end

  defp get_guilds_from_api(id, token) do
        case HTTPoison.get(@guilds_url, [{"Authorization", "Bearer #{token.token}"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        guild_data = Poison.decode! body
        set_guilds id, guild_data
        {:ok, %{"guilds" => guild_data}}
      {:ok, %HTTPoison.Response{status_code: 429, body: body}} ->
        res = Poison.decode! body
        retry = res["retry_after"] + 250
        Logger.warn  "Ratelimited on #{id} guilds, retry in #{retry}"
        Process.sleep retry # Wait a bit extra to be safe

        guild_res = HTTPoison.get! @guilds_url, [{"Authorization", "Bearer #{token.token}"}]
        guild_data = Poison.decode! guild_res.body
        set_guilds id, guild_data
        {:ok, %{"guilds" => guild_data}}
      _ ->
        {:error, :invalid_token}
    end
  end

  #############
  # USER DATA #
  #############

  def get_user(id) when is_binary(id) do
    {:ok, data} = Redis.q ["HGET", @user_store, id]
    case data do
      :undefined -> nil
      _ -> Poison.decode!(data)
    end
  end

  def set_user(id, data) when is_binary(id) do
    Redis.q ["HSET", @user_store, id, Poison.encode!(data)]
  end

  ##############
  # GUILD DATA #
  ##############

  def get_guilds(id) when is_binary(id) do
    {:ok, data} = Redis.q ["HGET", @guild_store, id]
    case data do
      :undefined -> nil
      _ -> Poison.decode!(data)
    end
  end

  def set_guilds(id, data) when is_binary(id) do
    Redis.q ["HSET", @guild_store, id, Poison.encode!(data)]
  end
end
