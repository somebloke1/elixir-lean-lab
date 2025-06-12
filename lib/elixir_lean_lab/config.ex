defmodule ElixirLeanLab.Config do
  @moduledoc """
  Configuration management for minimal VM builds.
  """

  defstruct [
    :type,
    :target_size,
    :app_path,
    :output_dir,
    :kernel_config,
    :packages,
    :strip_modules,
    :compression,
    :vm_options
  ]

  @defaults %{
    type: :alpine,
    target_size: 30,
    output_dir: "./build",
    kernel_config: :minimal,
    packages: [],
    strip_modules: true,
    compression: :xz,
    vm_options: %{
      memory: 256,
      cpus: 1
    }
  }

  @doc """
  Create a new configuration with default values.
  """
  def new(opts \\ []) do
    config = Enum.into(opts, @defaults)
    
    %__MODULE__{
      type: config[:type],
      target_size: config[:target_size],
      app_path: config[:app],
      output_dir: config[:output_dir],
      kernel_config: config[:kernel_config],
      packages: config[:packages],
      strip_modules: config[:strip_modules],
      compression: config[:compression],
      vm_options: Map.merge(@defaults.vm_options, config[:vm_options] || %{})
    }
  end

  @doc """
  Validate configuration.
  """
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_type(config.type),
         :ok <- validate_target_size(config.target_size),
         :ok <- validate_app_path(config.app_path) do
      {:ok, config}
    end
  end

  defp validate_type(type) when type in [:alpine, :buildroot, :nerves, :custom], do: :ok
  defp validate_type(type), do: {:error, "Invalid VM type: #{inspect(type)}"}

  defp validate_target_size(size) when is_integer(size) and size > 0, do: :ok
  defp validate_target_size(size), do: {:error, "Invalid target size: #{inspect(size)}"}

  defp validate_app_path(nil), do: :ok
  defp validate_app_path(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Application path does not exist: #{path}"}
    end
  end

  @doc """
  Get build configuration as JSON.
  """
  def to_json(%__MODULE__{} = config) do
    %{
      architecture: %{
        name: "minimal-vm-#{config.type}",
        version: "1.0",
        approach: to_string(config.type),
        target_size: "#{config.target_size}MB",
        build_method: build_method(config.type)
      },
      build: %{
        kernel_config: config.kernel_config,
        packages: config.packages,
        strip_modules: config.strip_modules,
        compression: config.compression
      },
      runtime: %{
        vm_options: config.vm_options
      }
    }
    |> Jason.encode!(pretty: true)
  end

  defp build_method(:alpine), do: "docker-multi-stage"
  defp build_method(:buildroot), do: "buildroot-makefile"
  defp build_method(:nerves), do: "nerves-mix"
  defp build_method(:custom), do: "custom-kernel"
end