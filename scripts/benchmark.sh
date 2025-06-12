#!/bin/bash
# Benchmark script for Lean Pipeline performance testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "⚡ Lean Pipeline Benchmarks"
echo "=========================="
echo ""

cd "$PROJECT_ROOT"

# Create benchmark script
cat > benchmark_pipeline.exs << 'EOF'
# Benchmark: Lean Pipeline Performance

alias LeanPipeline, as: LP

defmodule Benchmark do
  def measure(name, fun) do
    IO.write("#{name}... ")
    
    {time, result} = :timer.tc(fun)
    time_ms = time / 1000
    
    IO.puts("#{Float.round(time_ms, 2)}ms")
    result
  end
  
  def compare_approaches() do
    data = Enum.to_list(1..100_000)
    
    IO.puts("\n📊 Comparing Enum vs Stream vs LeanPipeline (100k elements)")
    IO.puts(String.duplicate("-", 50))
    
    # Enum approach
    measure("Enum (eager)", fn ->
      data
      |> Enum.map(&(&1 * 2))
      |> Enum.filter(&(rem(&1, 3) == 0))
      |> Enum.take(1000)
    end)
    
    # Stream approach
    measure("Stream (lazy)", fn ->
      data
      |> Stream.map(&(&1 * 2))
      |> Stream.filter(&(rem(&1, 3) == 0))
      |> Enum.take(1000)
    end)
    
    # LeanPipeline approach
    measure("LeanPipeline", fn ->
      data
      |> LP.from_enumerable()
      |> LP.map(&(&1 * 2))
      |> LP.filter(&(rem(&1, 3) == 0))
      |> LP.take(1000)
      |> Enum.to_list()
    end)
  end
  
  def windowing_performance() do
    IO.puts("\n📊 Windowing Performance (1M elements)")
    IO.puts(String.duplicate("-", 50))
    
    data = Enum.to_list(1..1_000_000)
    
    Enum.each([100, 1000, 10000], fn window_size ->
      measure("Window size #{window_size}", fn ->
        data
        |> LP.from_enumerable()
        |> LP.window(:tumbling, size: window_size)
        |> Stream.run()
      end)
    end)
  end
  
  def parallel_processing() do
    IO.puts("\n📊 Parallel Processing Benchmark")
    IO.puts(String.duplicate("-", 50))
    
    expensive_operation = fn x ->
      # Simulate CPU-intensive work
      :crypto.hash(:sha256, :erlang.term_to_binary(x))
      x * 2
    end
    
    data = Enum.to_list(1..1000)
    
    measure("Sequential processing", fn ->
      data
      |> LP.from_enumerable()
      |> LP.map(expensive_operation)
      |> Enum.to_list()
    end)
    
    Enum.each([2, 4, 8], fn parallelism ->
      measure("Parallel (#{parallelism} workers)", fn ->
        data
        |> LP.Flow.create()
        |> LP.Flow.parallel(expensive_operation, parallelism)
        |> Enum.to_list()
      end)
    end)
  end
  
  def memory_efficiency() do
    IO.puts("\n📊 Memory Efficiency Test")
    IO.puts(String.duplicate("-", 50))
    
    # Large dataset that would be expensive to hold in memory
    measure("Processing 10M elements (lazy)", fn ->
      1..10_000_000
      |> LP.from_enumerable()
      |> LP.map(&(&1 * 2))
      |> LP.filter(&(rem(&1, 100) == 0))
      |> LP.take(1000)
      |> Enum.count()
    end)
    
    IO.puts("\n✅ Processed large dataset without loading all into memory")
  end
end

# Run benchmarks
IO.puts("🚀 Starting benchmarks...\n")

Benchmark.compare_approaches()
Benchmark.windowing_performance()
Benchmark.parallel_processing()
Benchmark.memory_efficiency()

IO.puts("\n🎯 Benchmark complete!")
EOF

# Run the benchmark
echo "Running performance benchmarks..."
echo "This may take a few moments..."
echo ""
mix run --no-halt benchmark_pipeline.exs

# Cleanup
rm -f benchmark_pipeline.exs

echo ""
echo "📈 Benchmarks finished!"