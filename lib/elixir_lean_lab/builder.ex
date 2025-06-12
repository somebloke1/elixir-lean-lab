defmodule ElixirLeanLab.Builder do
  @moduledoc """
  Core builder module that delegates to specific VM builders.
  """

  alias ElixirLeanLab.Config
  alias ElixirLeanLab.Builder.{Alpine, Buildroot, Nerves, Custom}

  @doc """
  Create a new builder based on configuration.
  """
  def new(%Config{} = config) do
    case Config.validate(config) do
      {:ok, config} ->
        builder = case config.type do
          :alpine -> Alpine
          :buildroot -> Buildroot
          :nerves -> Nerves
          :custom -> Custom
        end
        {:ok, {builder, config}}
      
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Build the VM image.
  """
  def build({builder_module, config}) do
    # Ensure output directory exists
    File.mkdir_p!(config.output_dir)
    
    # Delegate to specific builder
    builder_module.build(config)
  end

  @doc """
  Common build steps shared across builders.
  """
  def prepare_build_env(config) do
    build_dir = Path.join(config.output_dir, "build")
    File.mkdir_p!(build_dir)
    
    {:ok, build_dir}
  end

  @doc """
  Copy Elixir application if specified.
  """
  def prepare_app(nil, _build_dir), do: {:ok, nil}
  def prepare_app(app_path, build_dir) do
    app_name = Path.basename(app_path)
    dest = Path.join(build_dir, app_name)
    
    case File.cp_r(app_path, dest) do
      {:ok, _} -> {:ok, dest}
      {:error, reason} -> {:error, "Failed to copy app: #{inspect(reason)}"}
    end
  end

  @doc """
  Calculate and report image sizes.
  """
  def report_size(image_path) do
    case File.stat(image_path) do
      {:ok, %{size: size}} ->
        size_mb = Float.round(size / 1_048_576, 2)
        IO.puts("Image size: #{size_mb} MB (#{size} bytes)")
        {:ok, size_mb}
      
      {:error, reason} ->
        {:error, "Failed to get image size: #{inspect(reason)}"}
    end
  end
end