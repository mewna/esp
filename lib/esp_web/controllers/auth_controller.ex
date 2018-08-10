defmodule ESPWeb.AuthController do
  use ESPWeb, :controller
  plug Ueberauth

  require Logger

  def request(conn, params) do
    case params["provider"] do
      "finish_login" ->
        conn |> finish_login(%{})
      "fail_login" ->
        conn |> fail_login(%{})
      _ -> conn |> redirect(external: System.get_env("BASE_URL"))
    end
  end

  def delete(conn, _params) do
    conn
    |> redirect(external: System.get_env("BASE_URL"))
  end

  # Auth failed
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn |> redirect(to: "/auth/fail_login")
  end

  # Auth worked
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    # Get raw info
    raw_guilds = auth.extra.raw_info[:guilds]
    raw_user = auth.extra.raw_info[:user]
    id = raw_user["id"]
    ESP.Key.set_token id, auth.credentials
    ESP.Key.set_user id, raw_user
    ESP.Key.set_guilds id, raw_guilds

    conn
    |> fetch_session
    |> put_session("user", raw_user)
    |> redirect(to: "/auth/finish_login")
  end

  defp get_avatar_cdn_url(user) when is_map(user) do
    if Map.has_key?(user, "avatar") do
      avatar = user["avatar"]
      ext = case avatar do
              "a_" <> _ -> "gif"
              _ -> "png"
            end
      "https://cdn.discordapp.com/avatars/#{user["id"]}/#{avatar}.#{ext}"
    else
      avatar = user["discriminator"] |> String.to_integer
      avatar = rem avatar, 5
      "https://cdn.discordapp.com/avatars/#{avatar}.png"
    end
  end

  defp update_account(user) when is_map(user) do
    account = %{
      "username" => "",
      "displayName" => user["username"],
      "email" => user["email"],
      "discordAccountId" => user["id"],
      "avatar" => get_avatar_cdn_url(user),
    }
    account_id = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/links/discord/" <> account["discordAccountId"]).body
    account = unless is_nil(account_id) or account_id == "null" do
                Map.put account, "id", account_id
              else
                account
              end
    HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/account/update/oauth", Poison.encode!(account)).body
  end

  def finish_login(conn, _params) do
    user = conn |> fetch_session |> get_session("user")
    update_account user
    # Don't pass back `email` here
    {_, user_actual} = Map.pop user, "email"
    data = %{
      "type" => "login",
      "user" => user_actual,
      "key" => ESP.Key.get_new_key(user["id"]),
      "profile" => HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/links/discord/" <> user_actual["id"]).body
    }

    conn
    |> fetch_session
    |> delete_session("user")
    # > Using "*"
    # WHAT COULD GO WRONG:tm:
    |> html("""
        <script>
        window.opener.postMessage(#{Poison.encode!(data)}, "*");
        self.close();
        </script>
        """)
  end

  def fail_login(conn, _params) do
    html conn,
    """
    <pre>
    Couldn't log you in. Please close this window and try again.
    </pre>
    """
  end
end
