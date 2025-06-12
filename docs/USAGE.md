# Lean Pipeline Usage Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Core Concepts](#core-concepts)
4. [Basic Usage](#basic-usage)
5. [Pipeline Stages](#pipeline-stages)
6. [Advanced Features](#advanced-features)
7. [Performance Optimization](#performance-optimization)
8. [Error Handling](#error-handling)
9. [Testing Strategies](#testing-strategies)
10. [Best Practices](#best-practices)

## Introduction

The Lean Pipeline is a composable, stream-based data processing system that embodies Lean software development principles through Elixir's functional programming paradigm. It provides a declarative API for building efficient data transformation pipelines that minimize waste while maximizing value delivery.

### Key Benefits

- **Lazy Evaluation**: Process only what's needed, when it's needed
- **Composability**: Build complex pipelines from simple, reusable stages
- **Fault Tolerance**: Leverages OTP for robust error handling
- **Observability**: Built-in metrics and telemetry
- **Performance**: Efficient streaming with backpressure support

## Getting Started

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/somebloke1/elixir-lean-lab.git
   cd elixir-lean-lab
   ```

2. Run the setup script:
   ```bash
   ./scripts/setup.sh
   ```

3. Start an interactive shell:
   ```bash
   iex -S mix
   ```

### Quick Example

```elixir
alias LeanPipeline

# Simple transformation pipeline
result = 1..10
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&(&1 * 2))
|> LeanPipeline.filter(&(&1 > 10))
|> Enum.to_list()

# result => [12, 14, 16, 18, 20]
```

## Core Concepts

### Streams vs Eager Evaluation

The Lean Pipeline uses Elixir's Stream module under the hood, providing lazy evaluation:

```elixir
# This creates a pipeline but doesn't process any data yet
pipeline = 1..1_000_000
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&expensive_operation/1)
|> LeanPipeline.take(10)

# Data is only processed when consumed
result = Enum.to_list(pipeline)  # Only processes 10 elements!
```

### Composability

Pipelines are composable - you can build reusable pipeline segments:

```elixir
# Define reusable transformations
defmodule DataTransforms do
  def normalize_text(pipeline) do
    pipeline
    |> LeanPipeline.map(&String.trim/1)
    |> LeanPipeline.map(&String.downcase/1)
    |> LeanPipeline.filter(&(&1 != ""))
  end
  
  def extract_words(pipeline) do
    pipeline
    |> LeanPipeline.flat_map(&String.split/1)
    |> LeanPipeline.deduplicate()
  end
end

# Compose transformations
["  Hello World  ", "  FOO bar  "]
|> LeanPipeline.from_enumerable()
|> DataTransforms.normalize_text()
|> DataTransforms.extract_words()
|> Enum.to_list()
```

### Backpressure

The pipeline automatically handles backpressure to prevent memory exhaustion:

```elixir
# Process large file without loading it all into memory
File.stream!("huge_file.txt")
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&process_line/1)
|> LeanPipeline.filter(&valid?/1)
|> Stream.each(&write_to_output/1)
|> Stream.run()
```

## Basic Usage

### Creating Pipelines

```elixir
# From a list
pipeline = LeanPipeline.from_enumerable([1, 2, 3])

# From a range
pipeline = LeanPipeline.from_enumerable(1..100)

# From a stream
pipeline = LeanPipeline.from_enumerable(File.stream!("data.txt"))

# Empty pipeline (add source later)
pipeline = LeanPipeline.new()
```

### Running Pipelines

```elixir
# Convert to list (loads all results into memory)
results = pipeline |> Enum.to_list()

# Process with side effects
pipeline |> Stream.each(&IO.puts/1) |> Stream.run()

# Take only what you need
first_10 = pipeline |> Enum.take(10)

# Reduce to single value
sum = pipeline |> Enum.sum()
```

## Pipeline Stages

### Transform Stages

#### Map
Applies a function to each element:

```elixir
# Double each number
[1, 2, 3]
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&(&1 * 2))
|> Enum.to_list()
# => [2, 4, 6]

# Parse JSON strings
json_strings
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&Jason.decode!/1)
```

#### FlatMap
Maps each element to a collection and flattens:

```elixir
# Split sentences into words
["hello world", "foo bar"]
|> LeanPipeline.from_enumerable()
|> LeanPipeline.flat_map(&String.split/1)
|> Enum.to_list()
# => ["hello", "world", "foo", "bar"]

# Expand ranges
[[1..3], [4..6]]
|> LeanPipeline.from_enumerable()
|> LeanPipeline.flat_map(&Enum.to_list/1)
# => [1, 2, 3, 4, 5, 6]
```

### Filter Stages

#### Filter
Keeps only elements that match a predicate:

```elixir
# Keep even numbers
1..10
|> LeanPipeline.from_enumerable()
|> LeanPipeline.filter(&(rem(&1, 2) == 0))
# => [2, 4, 6, 8, 10]

# Filter by multiple conditions
users
|> LeanPipeline.from_enumerable()
|> LeanPipeline.filter(&(&1.age >= 18))
|> LeanPipeline.filter(&(&1.active))
```

#### Take
Limits the number of elements:

```elixir
# Take first 5
Stream.iterate(1, &(&1 + 1))
|> LeanPipeline.from_enumerable()
|> LeanPipeline.take(5)
# => [1, 2, 3, 4, 5]
```

#### Drop
Skips initial elements:

```elixir
# Skip header row
File.stream!("data.csv")
|> LeanPipeline.from_enumerable()
|> LeanPipeline.drop(1)
|> LeanPipeline.map(&parse_csv_row/1)
```

#### Deduplicate
Removes consecutive duplicates:

```elixir
# Remove consecutive duplicates
[1, 1, 2, 2, 2, 3, 1, 1]
|> LeanPipeline.from_enumerable()
|> LeanPipeline.deduplicate()
# => [1, 2, 3, 1]

# Deduplicate by key
events
|> LeanPipeline.from_enumerable()
|> LeanPipeline.deduplicate(by: & &1.user_id)
```

### Aggregation Stages

#### Window
Groups elements into windows:

```elixir
# Count-based tumbling window
1..10
|> LeanPipeline.from_enumerable()
|> LeanPipeline.window(:tumbling, size: 3)
# => [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]

# Time-based window
events
|> LeanPipeline.from_enumerable()
|> LeanPipeline.window(:tumbling, duration: 60_000)  # 1 minute windows

# Sliding window
1..5
|> LeanPipeline.from_enumerable()
|> LeanPipeline.window(:sliding, size: 3, slide: 1)
# => [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
```

### Observation Stages

#### Tap
Allows side effects without modifying the stream:

```elixir
# Debug logging
data
|> LeanPipeline.from_enumerable()
|> LeanPipeline.tap(&IO.inspect(&1, label: "Before"))
|> LeanPipeline.map(&transform/1)
|> LeanPipeline.tap(&IO.inspect(&1, label: "After"))

# Metrics collection
pipeline
|> LeanPipeline.tap(fn item ->
  :telemetry.execute([:my_app, :item_processed], %{count: 1}, %{type: item.type})
end)
```

## Advanced Features

### Parallel Processing

Process elements in parallel for CPU-intensive operations:

```elixir
alias LeanPipeline.Flow

data
|> Flow.create()
|> Flow.parallel(&expensive_computation/1, 8)  # 8 parallel workers
|> Enum.to_list()
```

### Batching

Group elements for bulk operations:

```elixir
# Batch by count
records
|> Flow.create()
|> Flow.batch(100)  # Groups of 100
|> Stream.each(&bulk_insert/1)
|> Stream.run()

# Batch by time
events
|> Flow.create()
|> Flow.batch(1000, 5_000)  # Max 1000 items or 5 seconds
|> Stream.each(&send_batch/1)
```

### Supervised Pipelines

Run pipelines under supervision for fault tolerance:

```elixir
# Start a supervised pipeline
{:ok, pid} = LeanPipeline.Supervisor.start_pipeline(pipeline)

# List running pipelines
LeanPipeline.Supervisor.list_pipelines()

# Stop a pipeline
LeanPipeline.Supervisor.stop_pipeline(pid)
```

## Performance Optimization

### Memory Efficiency

```elixir
# Bad: Loads entire file into memory
File.read!("huge.txt")
|> String.split("\n")
|> Enum.map(&process/1)

# Good: Streams line by line
File.stream!("huge.txt")
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&process/1)
|> Stream.run()
```

### Avoiding Intermediate Collections

```elixir
# Bad: Creates intermediate lists
data
|> Enum.map(&step1/1)
|> Enum.filter(&step2/1)
|> Enum.map(&step3/1)

# Good: Single pass through data
data
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&step1/1)
|> LeanPipeline.filter(&step2/1)
|> LeanPipeline.map(&step3/1)
|> Enum.to_list()
```

### Parallelism Guidelines

Use parallel processing when:
- Operations are CPU-intensive
- Elements can be processed independently
- Order can be preserved or doesn't matter

```elixir
# Good candidate for parallelism
images
|> Flow.create()
|> Flow.parallel(&resize_image/1, System.schedulers_online())

# Poor candidate (I/O bound)
urls
|> LeanPipeline.from_enumerable()
|> LeanPipeline.map(&fetch_url/1)  # Better to use concurrent requests
```

## Error Handling

### Stage-Level Error Handling

Each stage tracks errors via telemetry:

```elixir
# Subscribe to error events
:telemetry.attach(
  "pipeline-errors",
  [:lean_pipeline, :stage, :error],
  fn _event, _measurements, metadata, _config ->
    Logger.error("Pipeline error: #{inspect(metadata.error)}")
  end,
  nil
)
```

### Pipeline-Level Error Recovery

```elixir
defmodule SafePipeline do
  def process_with_recovery(data) do
    data
    |> LeanPipeline.from_enumerable()
    |> LeanPipeline.map(&safe_transform/1)
    |> LeanPipeline.filter(&valid?/1)
    |> Enum.to_list()
  rescue
    error ->
      Logger.error("Pipeline failed: #{inspect(error)}")
      []  # Return empty result on failure
  end
  
  defp safe_transform(item) do
    try do
      dangerous_operation(item)
    rescue
      _ -> {:error, item}
    end
  end
  
  defp valid?({:error, _}), do: false
  defp valid?(_), do: true
end
```

## Testing Strategies

### Unit Testing Stages

```elixir
defmodule MyCustomStageTest do
  use ExUnit.Case
  
  test "processes elements correctly" do
    result = [1, 2, 3]
    |> MyCustomStage.process(my_option: true)
    |> Enum.to_list()
    
    assert result == [2, 4, 6]
  end
end
```

### Property-Based Testing

```elixir
use ExUnitProperties

property "pipeline preserves element count without filters" do
  check all elements <- list_of(term()) do
    result = elements
    |> LeanPipeline.from_enumerable()
    |> LeanPipeline.map(& &1)
    |> Enum.to_list()
    
    assert length(result) == length(elements)
  end
end
```

### Integration Testing

```elixir
test "end-to-end pipeline processing" do
  # Create test data
  File.write!("test_input.txt", "line1\nline2\nline3")
  
  # Run pipeline
  result = File.stream!("test_input.txt")
  |> LeanPipeline.from_enumerable()
  |> LeanPipeline.map(&String.trim/1)
  |> LeanPipeline.map(&String.upcase/1)
  |> Enum.to_list()
  
  assert result == ["LINE1", "LINE2", "LINE3"]
  
  # Cleanup
  File.rm!("test_input.txt")
end
```

## Best Practices

### 1. Prefer Streams for Large Data

```elixir
# Good: Constant memory usage
Stream.repeatedly(fn -> :rand.uniform() end)
|> LeanPipeline.from_enumerable()
|> LeanPipeline.take(1_000_000)
|> LeanPipeline.filter(&(&1 > 0.5))
|> Enum.count()
```

### 2. Order Operations Efficiently

```elixir
# Filter early to reduce processing
data
|> LeanPipeline.from_enumerable()
|> LeanPipeline.filter(&cheap_predicate/1)    # Filter first
|> LeanPipeline.map(&expensive_transform/1)   # Then transform
```

### 3. Use Tap for Debugging

```elixir
pipeline
|> LeanPipeline.tap(&IO.inspect(&1, label: "Input"))
|> LeanPipeline.map(&transform/1)
|> LeanPipeline.tap(&IO.inspect(&1, label: "After transform"))
|> LeanPipeline.filter(&predicate/1)
|> LeanPipeline.tap(&IO.inspect(&1, label: "After filter"))
```

### 4. Monitor Performance

```elixir
# Setup metrics before running pipelines
LeanPipeline.Metrics.setup()

# Check metrics after processing
LeanPipeline.Metrics.summary()
```

### 5. Document Pipeline Intent

```elixir
defmodule LogProcessor do
  @doc """
  Processes application logs to extract and aggregate errors.
  
  Pipeline stages:
  1. Parse JSON log entries
  2. Filter for error level
  3. Extract error details
  4. Group by error type
  5. Count occurrences
  """
  def process_logs(log_stream) do
    log_stream
    |> LeanPipeline.from_enumerable()
    |> LeanPipeline.map(&Jason.decode!/1)
    |> LeanPipeline.filter(&(&1["level"] == "error"))
    |> LeanPipeline.map(&extract_error_info/1)
    |> LeanPipeline.window(:tumbling, size: 1000)
    |> LeanPipeline.map(&count_by_type/1)
  end
end
```

## Examples

### Log Processing Pipeline

```elixir
defmodule LogAnalyzer do
  alias LeanPipeline
  
  def analyze_logs(file_path) do
    File.stream!(file_path)
    |> LeanPipeline.from_enumerable()
    |> LeanPipeline.map(&parse_log_line/1)
    |> LeanPipeline.filter(&error_or_warning?/1)
    |> LeanPipeline.window(:tumbling, duration: 60_000)
    |> LeanPipeline.map(&summarize_window/1)
    |> LeanPipeline.tap(&send_alert_if_critical/1)
    |> Enum.to_list()
  end
  
  defp parse_log_line(line) do
    case Regex.run(~r/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (.+)/, line) do
      [_, timestamp, level, message] ->
        %{timestamp: timestamp, level: level, message: message}
      _ ->
        nil
    end
  end
  
  defp error_or_warning?(%{level: level}), do: level in ["ERROR", "WARNING"]
  defp error_or_warning?(_), do: false
  
  defp summarize_window(logs) do
    %{
      window_start: List.first(logs).timestamp,
      error_count: Enum.count(logs, &(&1.level == "ERROR")),
      warning_count: Enum.count(logs, &(&1.level == "WARNING")),
      samples: Enum.take(logs, 5)
    }
  end
  
  defp send_alert_if_critical(%{error_count: count} = summary) when count > 10 do
    IO.puts("🚨 CRITICAL: #{count} errors in window starting at #{summary.window_start}")
  end
  defp send_alert_if_critical(_), do: :ok
end
```

### Data ETL Pipeline

```elixir
defmodule ETLPipeline do
  alias LeanPipeline
  alias LeanPipeline.Flow
  
  def process_csv(input_file, output_file) do
    File.stream!(input_file)
    |> LeanPipeline.from_enumerable()
    |> LeanPipeline.drop(1)  # Skip header
    |> LeanPipeline.map(&parse_csv_row/1)
    |> LeanPipeline.filter(&valid_record?/1)
    |> LeanPipeline.map(&transform_record/1)
    |> LeanPipeline.deduplicate(by: & &1.id)
    |> Flow.batch(1000)
    |> Stream.each(&write_batch_to_file(&1, output_file))
    |> Stream.run()
  end
  
  defp parse_csv_row(line) do
    line
    |> String.trim()
    |> String.split(",")
    |> then(fn [id, name, email, age] ->
      %{
        id: id,
        name: name,
        email: email,
        age: String.to_integer(age)
      }
    end)
  end
  
  defp valid_record?(record) do
    record.age >= 18 and 
    String.contains?(record.email, "@") and
    record.name != ""
  end
  
  defp transform_record(record) do
    %{
      record | 
      name: String.upcase(record.name),
      email: String.downcase(record.email)
    }
  end
  
  defp write_batch_to_file(batch, file) do
    content = batch
    |> Enum.map(&record_to_csv/1)
    |> Enum.join("\n")
    
    File.write!(file, content <> "\n", [:append])
  end
  
  defp record_to_csv(record) do
    "#{record.id},#{record.name},#{record.email},#{record.age}"
  end
end
```

### Real-time Stream Processing

```elixir
defmodule StreamProcessor do
  alias LeanPipeline
  
  def process_events(event_stream) do
    event_stream
    |> LeanPipeline.from_enumerable()
    |> LeanPipeline.map(&decode_event/1)
    |> LeanPipeline.filter(&relevant?/1)
    |> LeanPipeline.window(:sliding, size: 100, slide: 10)
    |> LeanPipeline.map(&calculate_metrics/1)
    |> LeanPipeline.tap(&update_dashboard/1)
    |> Stream.run()
  end
  
  defp decode_event(raw_event) do
    Jason.decode!(raw_event)
  end
  
  defp relevant?(event) do
    event["type"] in ["purchase", "view", "click"]
  end
  
  defp calculate_metrics(window) do
    %{
      window_size: length(window),
      purchases: Enum.count(window, &(&1["type"] == "purchase")),
      revenue: window
        |> Enum.filter(&(&1["type"] == "purchase"))
        |> Enum.map(&(&1["amount"]))
        |> Enum.sum(),
      avg_response_time: window
        |> Enum.map(&(&1["response_time"]))
        |> then(&(Enum.sum(&1) / length(&1)))
    }
  end
  
  defp update_dashboard(metrics) do
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "metrics:realtime",
      {:metrics_update, metrics}
    )
  end
end
```

## Troubleshooting

### Common Issues

1. **Memory Growth**
   - Ensure you're using streams, not eager operations
   - Check for accidental list conversions
   - Monitor with `:observer.start()`

2. **Slow Performance**
   - Profile with `:fprof` or `:eprof`
   - Consider parallel processing
   - Check for N+1 query patterns

3. **Pipeline Hangs**
   - Check for infinite streams without limits
   - Verify all stages are lazy
   - Use timeouts for external operations

### Debug Techniques

```elixir
# Enable debug logging
Logger.configure(level: :debug)

# Trace pipeline execution
pipeline
|> LeanPipeline.tap(fn x -> 
  IO.inspect(x, label: "Processing", limit: :infinity)
end)

# Count elements at each stage
pipeline
|> LeanPipeline.tap(fn _ -> Agent.update(counter, &(&1 + 1)) end)
```

## Next Steps

- Explore the [Architecture Documentation](ARCHITECTURE.md)
- Run the examples with `./scripts/demo.sh`
- Run benchmarks with `./scripts/benchmark.sh`
- Contribute to the project on [GitHub](https://github.com/somebloke1/elixir-lean-lab)