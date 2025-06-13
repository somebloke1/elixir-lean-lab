#!/usr/bin/env elixir

# Test script for Alpine Docker builder
# This tests the most basic functionality without requiring a full app

Mix.install([])

# Add the lib directory to the path
Code.prepend_path("_build/dev/lib/elixir_lean_lab/ebin")

alias ElixirLeanLab.{Config, Builder}

IO.puts("Testing Alpine Docker builder...")

# Create a minimal config
config = %Config{
  type: :alpine,
  app_path: nil,  # No app, just basic Elixir
  output_dir: "./output",
  target_size: 100,
  strip_modules: true,
  compression: :xz
}

# Ensure output directory exists
File.mkdir_p!(config.output_dir)

# Load the builder module
Code.ensure_loaded(ElixirLeanLab.Builder.Alpine)

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