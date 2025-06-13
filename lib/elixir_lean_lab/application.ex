defmodule ElixirLeanLab.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # No supervisors needed at startup
    ]

    opts = [strategy: :one_for_one, name: ElixirLeanLab.Supervisor]
    Supervisor.start_link(children, opts)
  end
end