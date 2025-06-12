defmodule LeanPipeline.Metrics do
  @moduledoc """
  Telemetry-based metrics collection for pipeline monitoring.
  
  Tracks throughput, latency, errors, and resource usage to provide
  visibility into pipeline performance and health.
  
  ## Metrics Collected
  
  - **Throughput**: Elements processed per second
  - **Latency**: Processing time per element
  - **Errors**: Failed processing attempts
  - **Buffer Usage**: Memory and queue depths
  - **Stage Performance**: Per-stage metrics
  
  ## Usage
  
      # Setup metrics handlers
      LeanPipeline.Metrics.setup()
      
      # Metrics are automatically collected during pipeline execution
      pipeline
      |> LeanPipeline.run()
      |> Enum.to_list()
  
  """
  
  require Logger
  
  @prefix [:lean_pipeline]
  
  @doc """
  Sets up telemetry handlers for pipeline metrics.
  
  Should be called once during application startup.
  """
  @spec setup() :: :ok
  def setup do
    handlers = [
      {[:lean_pipeline, :pipeline, :start], &handle_pipeline_start/4},
      {[:lean_pipeline, :pipeline, :complete], &handle_pipeline_complete/4},
      {[:lean_pipeline, :stage, :start], &handle_stage_start/4},
      {[:lean_pipeline, :stage, :stop], &handle_stage_stop/4},
      {[:lean_pipeline, :stage, :error], &handle_stage_error/4},
      {[:lean_pipeline, :flow, :backpressure], &handle_backpressure/4}
    ]
    
    Enum.each(handlers, fn {event, handler} ->
      :telemetry.attach(
        handler_id(event),
        event,
        handler,
        nil
      )
    end)
    
    :ok
  end
  
  @doc """
  Records a telemetry event with measurements and metadata.
  """
  @spec record_event(list(atom()), map(), map()) :: :ok
  def record_event(event_name, measurements, metadata) do
    :telemetry.execute(
      @prefix ++ event_name,
      measurements,
      metadata
    )
  end
  
  @doc """
  Returns current metrics summary.
  """
  @spec summary() :: map()
  def summary do
    %{
      pipelines_started: get_counter(:pipelines_started),
      pipelines_completed: get_counter(:pipelines_completed),
      total_elements_processed: get_counter(:elements_processed),
      total_errors: get_counter(:errors),
      average_latency_ms: get_average(:latency),
      backpressure_events: get_counter(:backpressure_events)
    }
  end
  
  # Event Handlers
  
  defp handle_pipeline_start(_event, measurements, metadata, _config) do
    increment_counter(:pipelines_started)
    
    Logger.debug("Pipeline started", 
      stage_count: measurements[:stage_count],
      pipeline: inspect(metadata[:pipeline])
    )
  end
  
  defp handle_pipeline_complete(_event, measurements, _metadata, _config) do
    increment_counter(:pipelines_completed)
    
    duration_ms = System.convert_time_unit(
      measurements[:duration],
      :native,
      :millisecond
    )
    
    record_latency(duration_ms)
    
    Logger.debug("Pipeline completed in #{duration_ms}ms")
  end
  
  defp handle_stage_start(_event, measurements, metadata, _config) do
    Logger.debug("Stage started",
      stage: metadata[:stage],
      element_count: measurements[:element_count]
    )
  end
  
  defp handle_stage_stop(_event, measurements, metadata, _config) do
    increment_counter(:elements_processed, measurements[:element_count] || 1)
    
    if duration = measurements[:duration] do
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)
      
      Logger.debug("Stage completed",
        stage: metadata[:stage],
        duration_ms: duration_ms,
        element_count: measurements[:element_count]
      )
    end
  end
  
  defp handle_stage_error(_event, _measurements, metadata, _config) do
    increment_counter(:errors)
    
    Logger.error("Stage error",
      stage: metadata[:stage],
      error: inspect(metadata[:error]),
      element: inspect(metadata[:element])
    )
  end
  
  defp handle_backpressure(_event, measurements, _metadata, _config) do
    increment_counter(:backpressure_events)
    
    Logger.warning("Backpressure applied",
      buffer_size: measurements[:buffer_size]
    )
  end
  
  # Storage helpers (using ETS for simplicity)
  
  defp ensure_table do
    case :ets.whereis(__MODULE__) do
      :undefined ->
        :ets.new(__MODULE__, [:named_table, :public, :set])
      tid ->
        tid
    end
  end
  
  defp increment_counter(key, amount \\ 1) do
    ensure_table()
    :ets.update_counter(__MODULE__, key, amount, {key, 0})
  end
  
  defp get_counter(key) do
    ensure_table()
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end
  
  defp record_latency(duration_ms) do
    ensure_table()
    key = :latency_samples
    
    case :ets.lookup(__MODULE__, key) do
      [{^key, {sum, count}}] ->
        :ets.insert(__MODULE__, {key, {sum + duration_ms, count + 1}})
      [] ->
        :ets.insert(__MODULE__, {key, {duration_ms, 1}})
    end
  end
  
  defp get_average(:latency) do
    ensure_table()
    case :ets.lookup(__MODULE__, :latency_samples) do
      [{:latency_samples, {sum, count}}] when count > 0 ->
        Float.round(sum / count, 2)
      _ ->
        0.0
    end
  end
  
  defp handler_id(event) do
    event
    |> Enum.join(".")
    |> String.to_atom()
  end
end