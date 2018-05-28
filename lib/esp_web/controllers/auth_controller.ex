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
    ESP.Key.set_key id

    conn 
    |> fetch_session
    |> put_session("user", raw_user)
    |> redirect(to: "/auth/finish_login")
  end

  def finish_login(conn, _params) do
    user = conn |> fetch_session |> get_session("user")
    data = %{
      "type" => "login",
      "user" => user,
      "key" => ESP.Key.get_key(user["id"])
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