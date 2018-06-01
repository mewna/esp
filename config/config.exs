# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :esp, ESPWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "ceyLRu1KcBmVGcGvBS/5obRDCt55hwSqYyAoRxUFYrzjhM4QSUP2ZDqDiHVmMiL3",
  render_errors: [view: ESPWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: ESP.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :ueberauth, Ueberauth,
  providers: [
    discord: {Ueberauth.Strategy.Discord, [default_scope: "identify guilds email connections"]}
  ]

config :ueberauth, Ueberauth.Strategy.Discord.OAuth,
  client_id: System.get_env("DISCORD_CLIENT_ID"),
  client_secret: System.get_env("DISCORD_CLIENT_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
