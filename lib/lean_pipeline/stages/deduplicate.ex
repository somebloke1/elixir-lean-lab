defmodule LeanPipeline.Stages.Deduplicate do
  @moduledoc """
  A pipeline stage that removes consecutive duplicate elements.
  
  This implements the "eliminate waste" Lean principle by removing
  redundant data from the stream. Only consecutive duplicates are
  removed to maintain streaming efficiency.
  
  ## Options
  
  - `:by` - Optional function to extract comparison key (default: identity)
  
  ## Example
  
      iex> [1, 1, 2, 2, 2, 3, 1, 1]
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.deduplicate()
      ...> |> Enum.to_list()
      [1, 2, 3, 1]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  alias LeanPipeline.Metrics
  
  @impl true
  def process(stream, opts) do
    key_fn = Keyword.get(opts, :by, & &1)
    
    unless is_function(key_fn, 1) do
      raise ArgumentError, ":by must be a function of arity 1"
    end
    
    Stream.transform(stream,
      fn -> :first end,
      fn element, acc ->
        key = key_fn.(element)
        
        case acc do
          :first ->
            {[element], key}
            
          ^key ->
            # Duplicate, skip
            Metrics.record_event(
              [:stage, :stop],
              %{element_count: 0},
              %{stage: __MODULE__, duplicate: true}
            )
            {[], key}
            
          _prev_key ->
            # Different, emit
            {[element], key}
        end
      end
    )
  end
  
  @impl true
  def describe do
    "Deduplicate"
  end
end