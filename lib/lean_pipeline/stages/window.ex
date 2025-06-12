defmodule LeanPipeline.Stages.Window do
  @moduledoc """
  A pipeline stage that groups elements into windows based on count or time.
  
  Supports tumbling windows (non-overlapping) and sliding windows (overlapping).
  
  ## Options
  
  - `:type` - Window type: `:tumbling` or `:sliding` (required)
  - `:size` - Number of elements per window (for count-based)
  - `:duration` - Time duration in milliseconds (for time-based)
  - `:slide` - Slide interval for sliding windows (default: same as size)
  
  ## Examples
  
      # Count-based tumbling window
      iex> 1..10
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.window(:tumbling, size: 3)
      ...> |> Enum.to_list()
      [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]
      
      # Time-based tumbling window
      stream
      |> LeanPipeline.window(:tumbling, duration: 1000)
  
  """
  
  @behaviour LeanPipeline.Stage
  
  alias LeanPipeline.Metrics
  
  @impl true
  def process(stream, opts) do
    type = Keyword.fetch!(opts, :type)
    
    case type do
      :tumbling -> tumbling_window(stream, opts)
      :sliding -> sliding_window(stream, opts)
      _ -> raise ArgumentError, "Unknown window type: #{inspect(type)}"
    end
  end
  
  @impl true
  def describe do
    "Window"
  end
  
  # Private functions
  
  defp tumbling_window(stream, opts) do
    cond do
      size = opts[:size] ->
        count_based_tumbling(stream, size)
        
      duration = opts[:duration] ->
        time_based_tumbling(stream, duration)
        
      true ->
        raise ArgumentError, "Window requires either :size or :duration"
    end
  end
  
  defp sliding_window(stream, opts) do
    size = Keyword.fetch!(opts, :size)
    slide = Keyword.get(opts, :slide, size)
    
    if slide > size do
      raise ArgumentError, "Slide interval cannot be larger than window size"
    end
    
    Stream.transform(stream,
      fn -> {:window, [], 0} end,
      fn element, {:window, buffer, count} ->
        new_buffer = buffer ++ [element]
        new_count = count + 1
        
        cond do
          new_count < size ->
            # Still filling initial window
            {[], {:window, new_buffer, new_count}}
            
          rem(new_count - size, slide) == 0 ->
            # Emit window and slide
            window = Enum.take(new_buffer, -size)
            {[window], {:window, Enum.drop(new_buffer, slide), new_count}}
            
          true ->
            # Keep accumulating
            {[], {:window, new_buffer, new_count}}
        end
      end,
      fn {:window, buffer, _count} ->
        # Emit final partial window if non-empty
        if buffer == [] do
          {[], :done}
        else
          {[buffer], :done}
        end
      end
    )
  end
  
  defp count_based_tumbling(stream, size) do
    stream
    |> Stream.chunk_every(size)
    |> Stream.map(fn window ->
      Metrics.record_event(
        [:stage, :stop],
        %{element_count: length(window)},
        %{stage: __MODULE__, window_type: :tumbling_count}
      )
      
      window
    end)
  end
  
  defp time_based_tumbling(stream, duration) do
    Stream.transform(stream,
      fn -> {:window, [], :erlang.monotonic_time(:millisecond)} end,
      fn element, {:window, buffer, start_time} ->
        now = :erlang.monotonic_time(:millisecond)
        
        if now - start_time >= duration do
          # Window complete, emit and start new
          window = Enum.reverse(buffer)
          
          Metrics.record_event(
            [:stage, :stop],
            %{element_count: length(window), duration: now - start_time},
            %{stage: __MODULE__, window_type: :tumbling_time}
          )
          
          {[window], {:window, [element], now}}
        else
          # Keep accumulating
          {[], {:window, [element | buffer], start_time}}
        end
      end,
      fn {:window, buffer, start_time} ->
        # Emit final window
        if buffer == [] do
          {[], :done}
        else
          window = Enum.reverse(buffer)
          now = :erlang.monotonic_time(:millisecond)
          
          Metrics.record_event(
            [:stage, :stop],
            %{element_count: length(window), duration: now - start_time},
            %{stage: __MODULE__, window_type: :tumbling_time, final: true}
          )
          
          {[window], :done}
        end
      end
    )
  end
end