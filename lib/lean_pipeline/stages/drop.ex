defmodule LeanPipeline.Stages.Drop do
  @moduledoc """
  A pipeline stage that drops the first N elements from the stream.
  
  Useful for skipping headers, warming up streams, or ignoring
  initial unstable data.
  
  ## Options
  
  - `:count` - Number of elements to drop (required)
  
  ## Example
  
      iex> 1..10
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.drop(5)
      ...> |> Enum.to_list()
      [6, 7, 8, 9, 10]
  
  """
  
  @behaviour LeanPipeline.Stage
  
  @impl true
  def process(stream, opts) do
    count = Keyword.fetch!(opts, :count)
    
    unless is_integer(count) and count >= 0 do
      raise ArgumentError, "count must be a non-negative integer"
    end
    
    Stream.drop(stream, count)
  end
  
  @impl true
  def describe do
    "Drop"
  end
end