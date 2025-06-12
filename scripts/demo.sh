#!/bin/bash
# Demo script showing Lean Pipeline examples

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔧 Lean Pipeline Demo"
echo "===================="
echo ""

cd "$PROJECT_ROOT"

# Create demo script
cat > demo_pipeline.exs << 'EOF'
# Demo: Lean Pipeline Examples

alias LeanPipeline, as: LP

IO.puts("\n📊 Example 1: Basic Transformations")
IO.puts("Processing numbers: doubling, filtering > 5")

result = 1..5
|> LP.from_enumerable()
|> LP.map(&(&1 * 2))
|> LP.filter(&(&1 > 5))
|> Enum.to_list()

IO.inspect(result, label: "Result")

# ----------------------------------------

IO.puts("\n📊 Example 2: Text Processing Pipeline")
IO.puts("Splitting text, filtering short words, uppercasing")

text = "The quick brown fox jumps over the lazy dog"
words = text
|> List.wrap()
|> LP.from_enumerable()
|> LP.flat_map(&String.split/1)
|> LP.filter(&(String.length(&1) > 3))
|> LP.map(&String.upcase/1)
|> Enum.to_list()

IO.inspect(words, label: "Long words")

# ----------------------------------------

IO.puts("\n📊 Example 3: Windowing for Batch Processing")
IO.puts("Grouping data into batches of 3")

batches = 1..10
|> LP.from_enumerable()
|> LP.window(:tumbling, size: 3)
|> LP.map(fn batch -> {length(batch), Enum.sum(batch)} end)
|> Enum.to_list()

IO.inspect(batches, label: "Batches (count, sum)")

# ----------------------------------------

IO.puts("\n📊 Example 4: Deduplication")
IO.puts("Removing consecutive duplicates")

unique = [1, 1, 2, 2, 2, 3, 1, 1, 4]
|> LP.from_enumerable()
|> LP.deduplicate()
|> Enum.to_list()

IO.inspect(unique, label: "Deduplicated")

# ----------------------------------------

IO.puts("\n📊 Example 5: Complex Pipeline")
IO.puts("Log processing simulation")

# Simulate log entries
logs = [
  "INFO: User login",
  "ERROR: Connection timeout",
  "INFO: Data processed",
  "ERROR: Database error",
  "WARNING: High memory usage",
  "INFO: Task completed",
  "ERROR: Authentication failed"
]

errors = logs
|> LP.from_enumerable()
|> LP.filter(&String.contains?(&1, "ERROR"))
|> LP.map(fn log ->
  [_, message] = String.split(log, ": ", parts: 2)
  %{severity: "ERROR", message: message, timestamp: DateTime.utc_now()}
end)
|> LP.take(5)  # Limit results
|> Enum.to_list()

IO.puts("\nError logs:")
Enum.each(errors, &IO.inspect/1)

# ----------------------------------------

IO.puts("\n📊 Example 6: Metrics Collection")
IO.puts("Starting metrics collection...")

# Setup metrics
LeanPipeline.Metrics.setup()

# Run pipeline with metrics
1..100
|> LP.from_enumerable()
|> LP.map(&(&1 * 2))
|> LP.filter(&(rem(&1, 3) == 0))
|> LP.window(:tumbling, size: 10)
|> LP.tap(fn window -> 
  IO.puts("Processing window of #{length(window)} elements")
end)
|> Stream.run()

# Display metrics summary
IO.puts("\nMetrics Summary:")
IO.inspect(LeanPipeline.Metrics.summary())

# ----------------------------------------

IO.puts("\n✅ Demo complete!")
EOF

# Run the demo
echo "Running pipeline examples..."
echo ""
mix run --no-halt demo_pipeline.exs

# Cleanup
rm -f demo_pipeline.exs

echo ""
echo "🎉 Demo finished!"