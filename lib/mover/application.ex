defmodule Mover.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # start mover process with initial value 15
      # oh this is how you can start multiple children
      Supervisor.child_spec({Mover.Mover, 15}, id: :long),
      Supervisor.child_spec({Mover.Mover, 5}, id: :short)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mover.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
