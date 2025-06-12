defmodule LeanPipeline.Stages.Map do
  @moduledoc """
  A pipeline stage that applies a transformation function to each element.
  
  This implements the classic map operation in a lazy, streaming fashion
  that maintains backpressure throughout the pipeline.
  
  ## Options
  
  - `:transform` - The function to apply to each element (required)
  
  ## Example
  
      iex> [1, 2, 3]
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.map(&(&1 * 2))
      ...> |> Enum.to_list()
      [2, 4, 6]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  alias LeanPipeline.Metrics
  
  @impl true
  def process(stream, opts) do
    transform = Keyword.fetch!(opts, :transform)
    
    unless is_function(transform, 1) do
      raise ArgumentError, "transform must be a function of arity 1"
    end
    
    Stream.map(stream, fn element ->
      start_time = System.monotonic_time()
      
      try do
        result = transform.(element)
        
        duration = System.monotonic_time() - start_time
        Metrics.record_event(
          [:stage, :stop],
          %{duration: duration, element_count: 1},
          %{stage: __MODULE__}
        )
        
        result
      rescue
        error ->
          Metrics.record_event(
            [:stage, :error],
            %{},
            %{stage: __MODULE__, error: error, element: element}
          )
          
          reraise error, __STACKTRACE__
      end
    end)
  end
  
  @impl true
  def describe do
    "Map"
  end
end