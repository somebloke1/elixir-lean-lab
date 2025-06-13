Mix.start()
Mix.Task.run("app.start")

alias ElixirLeanLab.{Config, Builder}

IO.puts("Testing Alpine Docker builder...")

# Create a minimal config
config = Config.new(
  type: :alpine,
  app: nil,  # No app, just basic Elixir
  output_dir: "./output",
  target_size: 100,
  strip_modules: true,
  compression: :xz
)

# Ensure output directory exists
File.mkdir_p!(config.output_dir)

# Test the build
case ElixirLeanLab.Builder.Alpine.build(config) do
  {:ok, result} ->
    IO.puts("✓ Build successful!")
    IO.puts("  Image: #{result.image}")
    IO.puts("  Size: #{result.size_mb} MB")
    IO.puts("  Type: #{result.type}")
    
  {:error, reason} ->
    IO.puts("✗ Build failed: #{reason}")
    System.halt(1)
end