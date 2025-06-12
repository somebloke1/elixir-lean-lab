defmodule LeanPipeline.Stages.Take do
  @moduledoc """
  A pipeline stage that takes only the first N elements from the stream.
  
  This stage demonstrates the "defer commitment" Lean principle by
  allowing early termination of processing when sufficient data
  has been collected.
  
  ## Options
  
  - `:count` - Number of elements to take (required)
  
  ## Example
  
      iex> Stream.iterate(1, &(&1 + 1))
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.take(5)
      ...> |> Enum.to_list()
      [1, 2, 3, 4, 5]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  @impl true
  def process(stream, opts) do
    count = Keyword.fetch!(opts, :count)
    
    unless is_integer(count) and count >= 0 do
      raise ArgumentError, "count must be a non-negative integer"
    end
    
    Stream.take(stream, count)
  end
  
  @impl true
  def describe do
    "Take"
  end
end