defmodule LeanPipeline.Flow do
  @moduledoc """
  Manages data flow through the pipeline with backpressure
  and demand-driven processing.
  
  This module provides utilities for creating efficient streams
  that respect system resources and prevent overwhelming downstream
  consumers.
  """
  
  alias LeanPipeline.Metrics
  
  @default_buffer_size 100
  @default_parallelism System.schedulers_online()
  
  @doc """
  Creates a stream from an enumerable with flow control.
  """
  @spec create(Enumerable.t(), keyword()) :: Stream.t()
  def create(enumerable, opts \\ []) do
    buffer_size = Keyword.get(opts, :buffer_size, @default_buffer_size)
    
    Stream.resource(
      fn -> init_flow_state(enumerable, buffer_size) end,
      &next_batch/1,
      &cleanup_flow_state/1
    )
  end
  
  @doc """
  Adds backpressure control to a stream.
  
  Limits the number of elements that can be buffered,
  preventing memory exhaustion and ensuring smooth flow.
  """
  @spec with_backpressure(Stream.t(), pos_integer()) :: Stream.t()
  def with_backpressure(stream, max_buffer) do
    Stream.transform(stream, 
      fn -> {:buffer, [], 0} end,
      fn element, {:buffer, buffer, count} ->
        if count >= max_buffer do
          Metrics.record_event(
            [:flow, :backpressure],
            %{buffer_size: count},
            %{}
          )
          
          # Apply backpressure by processing some buffered elements
          {Enum.reverse(buffer) ++ [element], {:buffer, [], 0}}
        else
          {[], {:buffer, [element | buffer], count + 1}}
        end
      end,
      fn {:buffer, buffer, _count} ->
        # Flush remaining buffer
        {Enum.reverse(buffer), :done}
      end
    )
  end
  
  @doc """
  Processes stream elements in parallel while maintaining order.
  
  Uses async tasks to process elements concurrently up to
  the specified parallelism level.
  """
  @spec parallel(Stream.t(), (any() -> any()), pos_integer()) :: Stream.t()
  def parallel(stream, transform_fn, parallelism \\ @default_parallelism) do
    stream
    |> Stream.chunk_every(parallelism)
    |> Stream.flat_map(fn chunk ->
      chunk
      |> Enum.map(fn element ->
        Task.async(fn -> transform_fn.(element) end)
      end)
      |> Enum.map(&Task.await/1)
    end)
  end
  
  @doc """
  Creates a flow that processes elements in batches.
  
  Useful for operations that benefit from bulk processing,
  such as database inserts or API calls.
  """
  @spec batch(Stream.t(), pos_integer(), timeout()) :: Stream.t() 
  def batch(stream, size, timeout \\ 5_000) do
    Stream.transform(stream,
      fn -> {:batch, [], 0, :erlang.monotonic_time(:millisecond)} end,
      fn element, {:batch, buffer, count, start_time} ->
        now = :erlang.monotonic_time(:millisecond)
        elapsed = now - start_time
        
        cond do
          count + 1 >= size ->
            # Batch is full
            {[Enum.reverse([element | buffer])], {:batch, [], 0, now}}
            
          elapsed >= timeout ->
            # Timeout reached
            {[Enum.reverse([element | buffer])], {:batch, [], 0, now}}
            
          true ->
            # Continue accumulating
            {[], {:batch, [element | buffer], count + 1, start_time}}
        end
      end,
      fn {:batch, buffer, _count, _start_time} ->
        # Flush final batch
        if buffer == [] do
          {[], :done}
        else
          {[Enum.reverse(buffer)], :done}
        end
      end
    )
  end
  
  # Private functions
  
  defp init_flow_state(enumerable, buffer_size) do
    ref = make_ref()
    
    Metrics.record_event(
      [:flow, :start],
      %{buffer_size: buffer_size},
      %{ref: ref}
    )
    
    {enumerable, ref}
  end
  
  defp next_batch({enumerable, ref}) do
    case Enumerable.reduce(enumerable, {:cont, []}, fn element, acc ->
      {:cont, [element | acc]}
    end) do
      {:done, elements} ->
        {Enum.reverse(elements), :done}
        
      {:suspended, elements, continuation} ->
        {Enum.reverse(elements), {continuation, ref}}
        
      {:halted, _elements} ->
        {:halt, ref}
    end
  end
  
  defp cleanup_flow_state(ref) when is_reference(ref) do
    Metrics.record_event(
      [:flow, :stop],
      %{},
      %{ref: ref}
    )
  end
  
  defp cleanup_flow_state(_), do: :ok
end