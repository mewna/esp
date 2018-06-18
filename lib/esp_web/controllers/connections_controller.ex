defmodule ESPWeb.ConnectionsController do
  use ESPWeb, :controller
  require Logger

  # Webhook URL format:
  # https://discordapp.com/oauth2/authorize
  #      ?response_type=code
  #      &client_id=CLIENT_ID
  #      &redirect_uri=CALLBACK_URL
  #      &scope=webhook.incoming
  #      &state=STATE
  #      &guild_id=GUILD_ID
  #      &channel_id=CHANNEL_ID
  #

  def discord_webhook_check(conn, params) do
    # Check to see if we already have a webhook for this guild/channel pair
    # If we do, no need to do more work and create a new one
    guild = params["guild"]
    channel = params["channel"]
    IO.puts guild
    IO.puts channel

    data = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/guild/#{guild}/webhooks/#{channel}").body |> Poison.decode!

    if Map.has_key?(data, "id") do
      conn |> json(%{exists: true})
    else
      conn |> json(%{exists: false})
    end
  end

  @doc """
  Params: guild, channel
  """
  def discord_webhook_start(conn, params) do
    guild = params["guild"]
    channel = params["channel"]

    redirect_url =
      URI.encode_www_form("#{System.get_env("DOMAIN")}/api/v1/connect/discord/webhooks/finish")

    conn
    |> redirect(
      external:
        "https://discordapp.com/oauth2/authorize?response_type=code" <>
          "&client_id=#{System.get_env("DISCORD_CLIENT_ID")}" <>
          "&redirect_uri=#{redirect_url}" <>
          "&scope=webhook.incoming" <> "&guild_id=#{guild}" <> "&channel_id=#{channel}"
    )
  end

  def discord_webhook_finish(conn, params) do
    uri =
      URI.encode_www_form("#{System.get_env("DOMAIN")}/api/v1/connect/discord/webhooks/finish")

    data = [
      "client_id=#{System.get_env("DISCORD_CLIENT_ID")}",
      "client_secret=#{System.get_env("DISCORD_CLIENT_SECRET")}",
      "grant_type=authorization_code",
      "code=#{params["code"]}",
      "redirect_uri=#{uri}",
      "scope=webhook.incoming"
    ]

    res =
      HTTPoison.post!("https://discordapp.com/api/v6/oauth2/token", Enum.join(data, "&"), [
        {"Content-Type", "application/x-www-form-urlencoded"}
      ]).body

    res = unless is_map(res) do
            Poison.decode!(res)
          else
            res
          end

    # {
    #  "token_type": "Bearer",
    #  "access_token": "memes",
    #  "scope": "webhook.incoming",
    #  "expires_in": probably doesn't matter,
    #  "refresh_token": "doesn't matter",
    #  "webhook": {
    #    "name": "memes",
    #    "url": "https://discordapp.com/api/webhooks/snowflakes/tokens!",
    #    "channel_id": "channel_id",
    #    "token": "tokens!",
    #    "avatar": "bot avatar id",
    #    "guild_id": "guild_id",
    #    "id": "snowflakes"
    #  }
    # }

    # Update webhook on the server
    webhook = %{
      "channel" => res["webhook"]["channel_id"],
      "guild" => res["webhook"]["guild_id"],
      "id" => res["webhook"]["id"],
      "secret" => res["webhook"]["token"]
    }

    HTTPoison.post!(
      System.get_env("INTERNAL_API") <> "/data/guild/#{webhook["guild"]}/webhooks/add",
      Poison.encode!(webhook),
      [{"Content-Type", "application/json"}]
    )

    # Tell the client that we're good and close the popup
    data = %{
      "hook_created" => true
    }
    conn
    |> html("""
            <script>
            window.opener.postMessage(#{Poison.encode!(data)}, "*");
            self.close();
            </script>
            """)
  end
end
