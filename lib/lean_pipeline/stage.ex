defmodule LeanPipeline.Stage do
  @moduledoc """
  Defines the behavior for pipeline stages.
  
  Each stage must implement process/2 to transform a stream,
  and describe/0 to provide a human-readable description.
  
  ## Example Implementation
  
      defmodule MyStage do
        @behaviour LeanPipeline.Stage
        
        @impl true
        def process(stream, opts) do
          transform = Keyword.fetch!(opts, :transform)
          Stream.map(stream, transform)
        end
        
        @impl true
        def describe do
          "MyStage"
        end
      end
  
  """
  
  @doc """
  Processes a stream through this stage with the given options.
  
  The stage should return a new stream that applies its transformation
  lazily. This enables the pipeline to maintain backpressure and
  process data efficiently.
  """
  @callback process(Stream.t(), keyword()) :: Stream.t()
  
  @doc """
  Returns a human-readable description of this stage.
  
  Used for debugging and pipeline visualization.
  """
  @callback describe() :: String.t()
  
  @doc """
  Checks if a module implements the Stage behaviour.
  """
  @spec valid?(module()) :: boolean()
  def valid?(module) do
    behaviours = module.module_info(:attributes)
    |> Keyword.get(:behaviour, [])
    
    __MODULE__ in behaviours
  end
end