defmodule LeanPipeline.Stages.Filter do
  @moduledoc """
  A pipeline stage that filters elements based on a predicate function.
  
  Only elements for which the predicate returns a truthy value
  are passed through to the next stage.
  
  ## Options
  
  - `:predicate` - The function to test each element (required)
  
  ## Example
  
      iex> [1, 2, 3, 4, 5]
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.filter(&(&1 > 3))
      ...> |> Enum.to_list()
      [4, 5]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  alias LeanPipeline.Metrics
  
  @impl true
  def process(stream, opts) do
    predicate = Keyword.fetch!(opts, :predicate)
    
    unless is_function(predicate, 1) do
      raise ArgumentError, "predicate must be a function of arity 1"
    end
    
    Stream.filter(stream, fn element ->
      start_time = System.monotonic_time()
      
      try do
        result = predicate.(element)
        
        duration = System.monotonic_time() - start_time
        Metrics.record_event(
          [:stage, :stop],
          %{duration: duration, element_count: 1},
          %{stage: __MODULE__, filtered: not result}
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
    "Filter"
  end
end