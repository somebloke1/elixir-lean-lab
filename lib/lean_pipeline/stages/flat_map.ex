defmodule LeanPipeline.Stages.FlatMap do
  @moduledoc """
  A pipeline stage that maps each element to a collection and flattens the result.
  
  This is useful for operations that produce multiple outputs per input,
  such as splitting strings or expanding nested data structures.
  
  ## Options
  
  - `:transform` - Function that returns an enumerable for each element (required)
  
  ## Example
  
      iex> ["hello world", "foo bar"]
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.flat_map(&String.split/1)
      ...> |> Enum.to_list()
      ["hello", "world", "foo", "bar"]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  alias LeanPipeline.Metrics
  
  @impl true
  def process(stream, opts) do
    transform = Keyword.fetch!(opts, :transform)
    
    unless is_function(transform, 1) do
      raise ArgumentError, "transform must be a function of arity 1"
    end
    
    Stream.flat_map(stream, fn element ->
      start_time = System.monotonic_time()
      
      try do
        result = transform.(element)
        
        unless Enumerable.impl_for(result) do
          raise ArgumentError, 
            "flat_map transform must return an enumerable, got: #{inspect(result)}"
        end
        
        # Convert to list to count elements
        result_list = Enum.to_list(result)
        
        duration = System.monotonic_time() - start_time
        Metrics.record_event(
          [:stage, :stop],
          %{duration: duration, element_count: length(result_list)},
          %{stage: __MODULE__, expansion_factor: length(result_list)}
        )
        
        result_list
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
    "FlatMap"
  end
end