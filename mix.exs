defmodule ESP.Mixfile do
  use Mix.Project

  def project do
    [
      app: :esp,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix, :gettext] ++ Mix.compilers,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ESP.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:uuid, "~> 1.1"},

      # OAuth2
      {:ueberauth, "~> 0.4"},
      {:ueberauth_discord, github: "getremia/ueberauth_discord"},

      # Redis
      {:lace, github: "queer/lace"},

      {:httpoison, "~> 1.1"},

      # CORS
      {:cors_plug, "~> 1.5"},
    ]
  end
end
