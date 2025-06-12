defmodule ElixirLeanLab do
  @moduledoc """
  ElixirLeanLab: Minimal VM Builder for Elixir Applications

  This module provides the main API for building minimal Linux VMs
  optimized for running Elixir applications. It supports multiple
  build strategies including Alpine Linux containers, custom kernel
  builds, and minimal root filesystem construction.
  """

  alias ElixirLeanLab.{Builder, Config, VM}

  @doc """
  Build a minimal VM image based on the provided configuration.
  
  ## Options
  
    * `:type` - VM type (:alpine, :buildroot, :nerves, :custom)
    * `:target_size` - Target image size in MB (default: 30)
    * `:app` - Path to Elixir application to include
    * `:output` - Output directory for VM artifacts
  
  ## Examples
  
      ElixirLeanLab.build(
        type: :alpine,
        target_size: 20,
        app: "./my_app",
        output: "./build"
      )
  """
  def build(opts \\ []) do
    config = Config.new(opts)
    
    with {:ok, builder} <- Builder.new(config),
         {:ok, artifacts} <- Builder.build(builder) do
      {:ok, artifacts}
    end
  end

  @doc """
  Create a new VM configuration.
  """
  def configure(opts \\ []) do
    Config.new(opts)
  end

  @doc """
  Launch a VM for testing.
  """
  def launch(image_path, opts \\ []) do
    VM.launch(image_path, opts)
  end

  @doc """
  Get size information for a VM image.
  """
  def analyze(image_path) do
    VM.analyze(image_path)
  end
end