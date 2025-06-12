defmodule LeanPipeline.Supervisor do
  @moduledoc """
  OTP supervisor for pipeline processes.
  
  Implements supervision strategies aligned with Lean principles:
  - Fail fast to identify problems quickly
  - Recover gracefully to maintain system stability
  - Isolate failures to prevent cascade effects
  
  ## Supervision Strategy
  
  Uses a `:one_for_one` strategy where each pipeline runs in isolation.
  If a pipeline crashes, only that pipeline is restarted, preventing
  cascading failures across the system.
  """
  
  use Supervisor
  
  alias LeanPipeline.{Metrics, Runner}
  
  @doc """
  Starts the pipeline supervisor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Starts a supervised pipeline.
  
  The pipeline will be automatically restarted if it crashes,
  up to the configured restart limit.
  """
  @spec start_pipeline(LeanPipeline.t(), keyword()) :: {:ok, pid()} | {:error, any()}
  def start_pipeline(pipeline, opts \\ []) do
    child_spec = %{
      id: make_ref(),
      start: {Runner, :start_link, [pipeline, opts]},
      restart: :transient,
      type: :worker
    }
    
    Supervisor.start_child(__MODULE__, child_spec)
  end
  
  @doc """
  Stops a running pipeline.
  """
  @spec stop_pipeline(pid()) :: :ok | {:error, :not_found}
  def stop_pipeline(pid) when is_pid(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end
  
  @doc """
  Lists all running pipelines.
  """
  @spec list_pipelines() :: [{pid(), LeanPipeline.t()}]
  def list_pipelines do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.map(fn {_id, pid, _type, _modules} ->
      case Runner.get_pipeline(pid) do
        {:ok, pipeline} -> {pid, pipeline}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  
  @impl true
  def init(opts) do
    # Setup metrics collection
    Metrics.setup()
    
    children = [
      # Could add persistent services here, like metrics aggregator
    ]
    
    max_restarts = Keyword.get(opts, :max_restarts, 3)
    max_seconds = Keyword.get(opts, :max_seconds, 5)
    
    Supervisor.init(children, 
      strategy: :one_for_one,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    )
  end
end

defmodule LeanPipeline.Runner do
  @moduledoc false
  # Internal module for running pipelines under supervision
  
  use GenServer
  
  def start_link(pipeline, opts) do
    GenServer.start_link(__MODULE__, {pipeline, opts})
  end
  
  def get_pipeline(pid) do
    GenServer.call(pid, :get_pipeline)
  catch
    :exit, _ -> {:error, :not_found}
  end
  
  @impl true
  def init({pipeline, opts}) do
    # Start pipeline processing in a separate process
    task = Task.async(fn ->
      pipeline
      |> LeanPipeline.run()
      |> Stream.run()
    end)
    
    {:ok, %{pipeline: pipeline, task: task, opts: opts}}
  end
  
  @impl true
  def handle_call(:get_pipeline, _from, %{pipeline: pipeline} = state) do
    {:reply, {:ok, pipeline}, state}
  end
  
  @impl true
  def handle_info({ref, result}, %{task: %Task{ref: ^ref}} = state) do
    # Pipeline completed successfully
    {:stop, :normal, state}
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task: %Task{ref: ^ref}} = state) do
    # Pipeline crashed
    {:stop, reason, state}
  end
end