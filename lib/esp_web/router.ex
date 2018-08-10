defmodule ESPWeb.Router do
  use ESPWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug #, [origin: System.get_env("BASE_URL")]
  end

  # We don't want to let people just flood the API with requests, but we also
  # know that some API routes need to have different ratelimits than others. To
  # deal with this, we define 3 basic ratelimit types - nice, medium, and
  # aggressive. They're exactly what they sound like - nice allows a good
  # number of requests, medium less so, then aggressive does heavy restrictions
  # on requests.

  pipeline :ratelimit_nice do
    #
  end

  pipeline :ratelimit_medium do
    #
  end

  pipeline :ratelimit_aggressive do
    #
  end

  scope "/api", ESPWeb do
    pipe_through :api

    scope "/v1" do
      scope "/cache" do
        get "/:type/:id",          ApiController, :cache

        get "/guild/:id/channels", ApiController, :cache_guild_channels
        get "/guild/:id/roles",    ApiController, :cache_guild_roles
        get "/guild/:id/exists",   ApiController, :cache_guild_exists
      end

      scope "/metadata" do
        get "/plugins", ApiController, :get_plugins
        get "/commands",  ApiController, :get_commands

        scope "/backgrounds" do
          get "/packs", ApiController, :backgrounds_packs
        end
      end

      scope "/data" do
        scope "/guild" do
          get  "/:id/webhooks",     ApiController, :webhooks_fetch
          get  "/:id/levels",       ApiController, :guild_levels_fetch
          post "/:id/config/:type", ApiController, :config_guild_update
          get  "/:id/config/:type", ApiController, :config_guild_fetch
        end

        scope "/account" do
          scope "/:id" do
            get  "/profile", ApiController, :account_get_profile
            post "/update",  ApiController, :account_update_profile
            get  "/posts",   ApiController, :account_get_posts
          end
          scope "/links" do
            get "/discord/:id", ApiController, :account_links_discord_id
          end
        end

        scope "/player" do
          get  "/:id", ApiController, :player_fetch
          post "/:id", ApiController, :player_update
        end

        scope "/twitch" do
          get "/lookup/name/:name", ApiController, :get_twitch_user_by_name
          get "/lookup/id/:id",     ApiController, :get_twitch_user_by_id
        end

        scope "/store" do
          get "/manifest", ApiController, :store_get_manifest
          scope "/checkout" do
            post "/start",   ApiController, :store_checkout_start
            get  "/confirm", ApiController, :store_checkout_confirm
          end
        end
      end

      scope "/connect" do
        scope "/discord" do
          scope "/bot" do
            get "/add/start",  ConnectionsController, :discord_bot_add_start
            get "/add/finish", ConnectionsController, :discord_bot_add_finish
          end
          scope "/webhooks" do
            get "/check",  ConnectionsController, :discord_webhook_check
            get "/start",  ConnectionsController, :discord_webhook_start
            get "/finish", ConnectionsController, :discord_webhook_finish
          end
        end
      end

      scope "/auth" do
        post "/logout", ApiController, :logout
      end

      get "/heartbeat", ApiController, :heartbeat
    end

    # tfw CORS is being rude
    # It didn't wanna work without this for some reason tho so bleh
    # Passing an "Authorization" header was triggering a CORS Preflight check
    # This deals with that by giving the right whatevers
    options "/*path", ApiController, :options
  end

  scope "/auth", ESPWeb do
    pipe_through :api

    get     "/:provider",           AuthController, :request
    get     "/:provider/callback",  AuthController, :callback
    post    "/:provider/callback",  AuthController, :callback
    get     "/logout",              AuthController, :delete
    get     "/finish_login",        AuthController, :finish_login
    options "/*path",               ApiController, :options
  end

  scope "/", ESPWeb do
    options "/*path", ApiController, :options
  end
end
