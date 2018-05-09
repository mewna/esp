defmodule ESPWeb.Router do
  use ESPWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug #, [origin: System.get_env("BASE_URL")]
  end

  scope "/api", ESPWeb do
    pipe_through :api

    scope "/cache" do
      get "/:type/:id",          ApiController, :cache

      get "/guild/:id/channels", ApiController, :cache_guild_channels
      get "/guild/:id/roles",    ApiController, :cache_guild_roles
    end

    scope "/config" do
      post "/update", ApiController, :config_update
      get  "/fetch",  ApiController, :config_fetch
    end

    scope "/auth" do
      post "/logout", ApiController, :logout
    end

    get     "/heartbeat", ApiController, :heartbeat
    get     "/commands",  ApiController, :get_commands
    # tfw CORS is being rude
    # It didn't wanna work without this for some reason tho so bleh
    # Passing an "Authorization" header was triggering a CORS Preflight check
    # This deals with that by giving the right whatevers
    options "/*path",     ApiController, :options
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
