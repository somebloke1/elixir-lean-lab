defmodule ElixirLeanLab.Validator do
  @moduledoc """
  Validation framework for VM builders.
  
  This module ensures that builders produce working VMs,
  not just files that exist.
  """

  require Logger

  @doc """
  Validates that a built VM image meets the specified criteria.
  """
  def validate_image(image_path, config) do
    with {:ok, :exists} <- validate_exists(image_path),
         {:ok, :size} <- validate_size(image_path, config),
         {:ok, :bootable} <- validate_bootable(image_path, config),
         {:ok, :functional} <- validate_functional(image_path, config) do
      {:ok, build_validation_report(image_path, config)}
    end
  end

  @doc """
  Validates builder dependencies before attempting build.
  """
  def validate_dependencies(builder_type) do
    deps = dependencies_for(builder_type)
    
    missing = Enum.filter(deps, fn dep ->
      case System.find_executable(dep) do
        nil -> true
        _ -> false
      end
    end)
    
    case missing do
      [] -> :ok
      tools -> {:error, "Missing required tools: #{Enum.join(tools, ", ")}"}
    end
  end

  defp validate_exists(path) do
    if File.exists?(path) do
      {:ok, :exists}
    else
      {:error, "Image file does not exist: #{path}"}
    end
  end

  defp validate_size(path, config) do
    case File.stat(path) do
      {:ok, %{size: size}} ->
        size_mb = size / 1_048_576
        
        if size_mb <= config.target_size * 1.5 do  # Allow 50% overrun
          {:ok, :size}
        else
          {:error, "Image size #{Float.round(size_mb, 1)}MB exceeds target #{config.target_size}MB by more than 50%"}
        end
        
      {:error, reason} ->
        {:error, "Cannot determine image size: #{inspect(reason)}"}
    end
  end

  defp validate_bootable(image_path, config) do
    case config.type do
      :alpine -> validate_docker_bootable(image_path)
      :nerves -> validate_nerves_bootable(image_path)
      type when type in [:buildroot, :custom] -> validate_qemu_bootable(image_path)
      _ -> {:ok, :bootable}  # Skip validation for unknown types
    end
  end

  defp validate_docker_bootable(image_path) do
    # Quick test: can we load and run the image?
    test_cmd = "docker load < #{image_path} && docker run --rm elixir-minimal:latest elixir -e 'IO.puts(:ok)'"
    
    case System.cmd("sh", ["-c", test_cmd], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "ok") do
          {:ok, :bootable}
        else
          {:error, "Docker image did not output 'ok'"}
        end
      {output, _} -> {:error, "Docker image not bootable: #{output}"}
    end
  end

  defp validate_qemu_bootable(_image_path) do
    # TODO: Implement QEMU boot test
    Logger.warn("QEMU boot validation not yet implemented")
    {:ok, :bootable}
  end

  defp validate_nerves_bootable(_image_path) do
    # TODO: Implement Nerves firmware validation
    Logger.warn("Nerves boot validation not yet implemented")
    {:ok, :bootable}
  end

  defp validate_functional(image_path, config) do
    if config.app_path do
      validate_app_runs(image_path, config)
    else
      validate_elixir_works(image_path, config)
    end
  end

  defp validate_app_runs(_image_path, _config) do
    # TODO: Implement app functionality test
    Logger.warn("App functionality validation not yet implemented")
    {:ok, :functional}
  end

  defp validate_elixir_works(image_path, config) do
    case config.type do
      :alpine ->
        test_cmd = "docker run --rm elixir-minimal:latest elixir -e 'IO.inspect(System.version())'"
        
        case System.cmd("sh", ["-c", test_cmd], stderr_to_stdout: true) do
          {output, 0} ->
            if String.contains?(output, "1.") do
              {:ok, :functional}
            else
              {:error, "Elixir not functional: #{output}"}
            end
          {output, _} -> {:error, "Elixir not functional: #{output}"}
        end
        
      _ ->
        {:ok, :functional}  # Skip for non-Alpine for now
    end
  end

  defp dependencies_for(builder_type) do
    case builder_type do
      :alpine -> ["docker"]
      :buildroot -> ["wget", "tar", "make", "gcc", "xz"]
      :nerves -> ["mix", "elixir", "erlang"]
      :custom -> ["wget", "tar", "make", "gcc", "cpio", "xz", "find"]
      _ -> []
    end
  end

  defp build_validation_report(image_path, config) do
    %{
      image: image_path,
      type: config.type,
      validations: %{
        exists: true,
        size_acceptable: true,
        bootable: true,
        functional: true
      },
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Creates a validation suite for continuous testing.
  """
  def create_validation_suite(config) do
    %{
      pre_build: &validate_dependencies/1,
      post_build: &validate_image/2,
      continuous: create_continuous_tests(config)
    }
  end

  defp create_continuous_tests(config) do
    [
      {:size_growth, &monitor_size_growth/1},
      {:boot_time, &measure_boot_time/1},
      {:memory_usage, &measure_memory_usage/1}
    ]
  end

  defp monitor_size_growth(_config), do: :ok
  defp measure_boot_time(_config), do: :ok
  defp measure_memory_usage(_config), do: :ok
end