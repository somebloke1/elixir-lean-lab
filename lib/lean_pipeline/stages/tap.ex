defmodule LeanPipeline.Stages.Tap do
  @moduledoc """
  A pipeline stage that allows observation of elements without modification.
  
  Useful for debugging, logging, metrics collection, or any side effect
  that needs to observe the data flow without transforming it.
  
  ## Options
  
  - `:effect` - Function to call for each element (required)
  
  ## Example
  
      iex> [1, 2, 3]
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.tap(&IO.inspect/1)
      ...> |> LeanPipeline.map(&(&1 * 2))
      ...> |> Enum.to_list()
      # Prints: 1, 2, 3
      [2, 4, 6]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  alias LeanPipeline.Metrics
  
  @impl true
  def process(stream, opts) do
    effect_fn = Keyword.fetch!(opts, :effect)
    
    unless is_function(effect_fn, 1) do
      raise ArgumentError, "effect must be a function of arity 1"
    end
    
    Stream.each(stream, fn element ->
      start_time = System.monotonic_time()
      
      try do
        effect_fn.(element)
        
        duration = System.monotonic_time() - start_time
        Metrics.record_event(
          [:stage, :stop],
          %{duration: duration, element_count: 1},
          %{stage: __MODULE__}
        )
      rescue
        error ->
          # Log error but don't interrupt stream
          Metrics.record_event(
            [:stage, :error],
            %{},
            %{stage: __MODULE__, error: error, element: element, non_fatal: true}
          )
      end
    end)
  end
  
  @impl true
  def describe do
    "Tap"
  end
end