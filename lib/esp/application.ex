defmodule ESP.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(ESPWeb.Endpoint, []),
      # Start your own worker by calling: ESP.Worker.start_link(arg1, arg2, arg3)
      # worker(ESP.Worker, [arg1, arg2, arg3]),
      {Lace.Redis, %{redis_ip: System.get_env("REDIS_IP"), redis_port: 6379, pool_size: 10, redis_pass: System.get_env("REDIS_PASS")}},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ESP.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ESPWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
