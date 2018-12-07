defmodule ESPWeb.BlogController do
  use ESPWeb, :controller
  require Logger

  defp get_key(conn) do
    conn |> get_req_header("authorization") |> hd
  end

  defp get_user(conn) do
    key = get_key conn
    {valid, id} = ESP.Key.check_key_valid key
    if valid do
      {:ok, id}
    else
      {:error, "no user"}
    end
  end

  defp key_owns_guild(conn, guild_id) do
    key = get_key conn
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

  def server_get_one_post(conn, params) do
    guild = params["id"]
    post = params["post"]
    response = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/server/#{guild}/post/#{post}").body
    conn |> json(response)
  end

  def server_edit_one_post(conn, params) do
    guild = params["id"]
    post = params["post"]
    {state, response} = key_owns_guild conn, guild
    case state do
      :ok ->
        title = params["title"]
        content = params["content"]
        {:ok, user_id} = get_user conn
        account_id = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/links/discord/" <> user_id).body
        data = %{
          "title" => title,
          "content" => content,
          "author" => account_id,
          "guild" => guild,
          "id" => post
        }
        response = HTTPoison.put!(System.get_env("INTERNAL_API") <> "/data/server/#{guild}/post/#{post}", Poison.encode!(data)).body
        conn |> json(Poison.decode!(response))
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  def server_delete_one_post(conn, params) do
    guild = params["id"]
    {state, response} = key_owns_guild conn, guild
    case state do
      :ok ->
        post = params["post"]
        HTTPoison.delete!(System.get_env("INTERNAL_API") <> "/data/server/#{guild}/post/#{post}")
        conn |> json(%{})
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  def server_post_create(conn, params) do
    guild = params["id"]
    {state, response} = key_owns_guild conn, guild
    case state do
      :ok ->
        title = params["title"]
        content = params["content"]
        {:ok, user_id} = get_user conn
        account_id = HTTPoison.get!(System.get_env("INTERNAL_API") <> "/data/account/links/discord/" <> user_id).body
        data = %{
          "title" => title,
          "content" => content,
          "author" => account_id,
          "guild" => guild,
        }
        response = HTTPoison.post!(System.get_env("INTERNAL_API") <> "/data/server/#{guild}/post", Poison.encode!(data)).body
        conn |> json(Poison.decode!(response))
      :error ->
        conn |> json(%{"error" => response})
    end
  end

  def server_get_posts(conn, params) do
    #
  end

  def server_get_all_posts(conn, params) do
    #
  end
end
