defmodule LeanPipeline do
  @moduledoc """
  Main entry point for building and running Lean pipelines.
  
  Provides a declarative API for constructing data processing pipelines
  that embody Lean software development principles through functional
  programming patterns.
  
  ## Example
  
      iex> [1, 2, 3, 4, 5]
      ...> |> LeanPipeline.from_enumerable()
      ...> |> LeanPipeline.map(&(&1 * 2))
      ...> |> LeanPipeline.filter(&(&1 > 5))
      ...> |> Enum.to_list()
      [6, 8, 10]
  
  """
  
  alias LeanPipeline.{Flow, Stage, Metrics}
  
  defstruct stages: [], config: %{}, source: nil, metrics: Metrics
  
  @type t :: %__MODULE__{
    stages: [stage_spec()],
    config: map(),
    source: Enumerable.t() | nil,
    metrics: module()
  }
  
  @type stage_spec :: {module(), keyword()}
  @type pipeline_option :: {:metrics, module()} | {:config, map()}
  
  @doc """
  Creates a new pipeline with optional configuration.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      metrics: Keyword.get(opts, :metrics, Metrics),
      config: Keyword.get(opts, :config, %{})
    }
  end
  
  @doc """
  Creates a pipeline from an enumerable source.
  """
  @spec from_enumerable(Enumerable.t(), keyword()) :: t()
  def from_enumerable(enumerable, opts \\ []) do
    %{new(opts) | source: enumerable}
  end
  
  @doc """
  Adds a map transformation stage to the pipeline.
  """
  @spec map(t(), (any() -> any())) :: t()
  def map(%__MODULE__{} = pipeline, transform_fn) do
    add_stage(pipeline, LeanPipeline.Stages.Map, transform: transform_fn)
  end
  
  @doc """
  Adds a filter stage to the pipeline.
  """
  @spec filter(t(), (any() -> boolean())) :: t()
  def filter(%__MODULE__{} = pipeline, predicate_fn) do
    add_stage(pipeline, LeanPipeline.Stages.Filter, predicate: predicate_fn)
  end
  
  @doc """
  Adds a flat_map transformation stage to the pipeline.
  """
  @spec flat_map(t(), (any() -> Enumerable.t())) :: t()
  def flat_map(%__MODULE__{} = pipeline, transform_fn) do
    add_stage(pipeline, LeanPipeline.Stages.FlatMap, transform: transform_fn)
  end
  
  @doc """
  Adds a windowing stage to the pipeline.
  """
  @spec window(t(), atom(), keyword()) :: t()
  def window(%__MODULE__{} = pipeline, type, opts) do
    add_stage(pipeline, LeanPipeline.Stages.Window, [type: type] ++ opts)
  end
  
  @doc """
  Adds a take stage to limit elements.
  """
  @spec take(t(), pos_integer()) :: t()
  def take(%__MODULE__{} = pipeline, count) do
    add_stage(pipeline, LeanPipeline.Stages.Take, count: count)
  end
  
  @doc """
  Adds a drop stage to skip elements.
  """
  @spec drop(t(), pos_integer()) :: t()
  def drop(%__MODULE__{} = pipeline, count) do
    add_stage(pipeline, LeanPipeline.Stages.Drop, count: count)
  end
  
  @doc """
  Adds a deduplication stage.
  """
  @spec deduplicate(t()) :: t()
  def deduplicate(%__MODULE__{} = pipeline) do
    add_stage(pipeline, LeanPipeline.Stages.Deduplicate, [])
  end
  
  @doc """
  Adds a tap stage for side effects.
  """
  @spec tap(t(), (any() -> any())) :: t()
  def tap(%__MODULE__{} = pipeline, side_effect_fn) do
    add_stage(pipeline, LeanPipeline.Stages.Tap, effect: side_effect_fn)
  end
  
  @doc """
  Runs the pipeline and returns a stream.
  """
  @spec run(t()) :: Stream.t()
  def run(%__MODULE__{source: nil}) do
    raise ArgumentError, "Pipeline has no source. Use from_enumerable/2 first."
  end
  
  def run(%__MODULE__{} = pipeline) do
    start_time = System.monotonic_time()
    
    Metrics.record_event(
      [:pipeline, :start],
      %{stage_count: length(pipeline.stages)},
      %{pipeline: pipeline}
    )
    
    stream = pipeline.stages
    |> Enum.reduce(Flow.create(pipeline.source), fn {stage_module, opts}, stream ->
      stage_module.process(stream, opts)
    end)
    
    Stream.transform(stream, fn -> start_time end, fn element, start_time ->
      {[element], start_time}
    end, fn start_time ->
      duration = System.monotonic_time() - start_time
      
      Metrics.record_event(
        [:pipeline, :complete],
        %{duration: duration},
        %{pipeline: pipeline}
      )
    end)
  end
  
  @doc """
  Adds a stage to the pipeline.
  """
  @spec add_stage(t(), module(), keyword()) :: t()
  def add_stage(%__MODULE__{} = pipeline, stage_module, opts) do
    unless Stage.valid?(stage_module) do
      raise ArgumentError, "#{inspect(stage_module)} does not implement LeanPipeline.Stage"
    end
    
    %{pipeline | stages: pipeline.stages ++ [{stage_module, opts}]}
  end
  
  @doc """
  Returns a description of the pipeline for debugging.
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{} = pipeline) do
    stages_desc = pipeline.stages
    |> Enum.map(fn {module, _opts} -> module.describe() end)
    |> Enum.join(" |> ")
    
    source_desc = if pipeline.source, do: "Source", else: "No source"
    
    "#{source_desc} |> #{stages_desc}"
  end
  
  defimpl Enumerable do
    def count(_pipeline), do: {:error, __MODULE__}
    def member?(_pipeline, _element), do: {:error, __MODULE__}
    def slice(_pipeline), do: {:error, __MODULE__}
    
    def reduce(pipeline, acc, fun) do
      pipeline
      |> LeanPipeline.run()
      |> Enumerable.reduce(acc, fun)
    end
  end
end