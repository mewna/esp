defmodule ESP.Key do
  alias Lace.Redis
  require Logger

  @key_store          "esp-key-store"
  @token_store        "esp-token-store"
  @user_store         "esp-user-store"
  @guild_store        "esp-guild-store"

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
    hmac = :crypto.hmac(:sha512, System.get_env("SIGNING_KEY"), id) |> Base.encode16
    "esp." <> encoded_id <> "." <> hmac
  end

  def get_key(id) when is_binary(id) do
    {:ok, key} = Redis.q ["HGET", @key_store, id]
    case key do
      :undefined -> set_key id
      _ -> key
    end
  end

  def set_key(id) when is_binary(id) do
    key = keygen id
    Redis.q ["HSET", @key_store, id, key]
    key
  end

  def clear_auth_by_key(nil) do
    # NOOP
  end
  def clear_auth_by_key(key) when is_binary(key) do
    Redis.q ["HDEL", @key_store, key]
  end

  def parse_key(key) do
    if key == "null" do
      # We just pass the token directly from whatever's in the auth. header, so
      # the client may actually send "null" and nothing else
      {false, nil}
    else
      [esp, id, hmac] = key |> String.split("\.", parts: 3)
      {_, id} = Base.decode16(id)
      valid = Base.encode16(:crypto.hmac(:sha512, System.get_env("SIGNING_KEY"), id)) == hmac
      {valid, id}
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
    # TODO
  end

  def refresh_data(id) when is_binary(id) do
    token = get_token id
    unless is_nil token do
      # TODO: Check expiry
      {_, user} = get_user_from_api id, token
      {_, guilds} = get_guilds_from_api id, token
      {:ok, %{"user" => user["user"], "guilds" => guilds["guilds"]}}
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
      _ ->
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
