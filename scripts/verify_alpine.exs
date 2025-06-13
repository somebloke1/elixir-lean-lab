#!/usr/bin/env elixir

# Create a test container from the runtime stage directly
cmd = """
docker run --rm elixir-lean-vm:1749796763 /usr/local/bin/elixir -e 'IO.puts("Elixir #{System.version()}")'
"""

IO.puts("Testing Elixir in minimal container...")
case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
  {output, 0} ->
    IO.puts("✓ Success!")
    IO.puts(output)
  {output, status} ->
    IO.puts("✗ Failed with status #{status}")
    IO.puts(output)
end