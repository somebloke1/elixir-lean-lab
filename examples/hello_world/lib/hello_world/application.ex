defmodule HelloWorld.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = []
    
    opts = [strategy: :one_for_one, name: HelloWorld.Supervisor]
    
    # Print hello message on startup
    Task.start(fn -> 
      Process.sleep(100)
      HelloWorld.hello()
    end)
    
    Supervisor.start_link(children, opts)
  end
end