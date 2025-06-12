defmodule ElixirLeanLab.Builder.Common do
  @moduledoc """
  Common functionality for VM builders.
  
  This module provides higher-level shared functionality:
  - Standard build result structures
  - Error handling patterns
  - Download and extract with caching
  - Script creation utilities
  - VM packaging helpers
  """
  
  alias ElixirLeanLab.Builder.Utils
  alias ElixirLeanLab.OTPStripper
  
  @doc """
  Create a standard build result structure.
  """
  def build_result(image_path, type, metadata \\ %{}) do
    base_result = %{
      image: image_path,
      type: type,
      size_mb: Utils.get_file_size_mb(image_path)
    }
    
    Map.merge(base_result, metadata)
  end
  
  @doc """
  Download and extract a tarball with caching.
  
  Only downloads if the extracted directory doesn't exist.
  """
  def download_and_extract(url, dest_dir, extract_name, opts \\ []) do
    extracted_path = Path.join(dest_dir, extract_name)
    
    if File.exists?(extracted_path) do
      {:ok, extracted_path}
    else
      tarball_name = Path.basename(url)
      tarball_path = Path.join(dest_dir, tarball_name)
      
      with {:ok, _} <- Utils.download_file(url, tarball_path),
           {:ok, _} <- Utils.extract_archive(tarball_path, dest_dir, opts) do
        # Clean up tarball after extraction
        File.rm(tarball_path)
        {:ok, extracted_path}
      end
    end
  end
  
  @doc """
  Compress a file and optionally remove the original.
  """
  def compress_and_cleanup(file_path, compression, keep_original \\ false) do
    case Utils.compress_file(file_path, compression, keep_original: keep_original) do
      {:ok, compressed_path} ->
        unless keep_original do
          File.rm(file_path)
        end
        {:ok, compressed_path}
      error ->
        error
    end
  end
  
  @doc """
  Create an executable script file.
  """
  def create_script(path, content, opts \\ []) do
    header = Keyword.get(opts, :header, "#!/bin/bash")
    full_content = header <> "\n" <> content
    
    Utils.write_file(path, full_content, executable: true)
  end
  
  @doc """
  Package VM components into a single archive.
  """
  def package_vm(files, output_path, opts \\ []) do
    compression = Keyword.get(opts, :compression, :xz)
    base_dir = Keyword.get(opts, :base_dir)
    
    # If base_dir is specified, make file paths relative to it
    relative_files = if base_dir do
      Enum.map(files, &Path.relative_to(&1, base_dir))
    else
      files
    end
    
    Utils.create_tar_archive(relative_files, output_path, 
                           compression: compression,
                           cd: base_dir)
  end
  
  @doc """
  Get OTP stripping configuration based on config options.
  """
  def get_otp_strip_opts(config) do
    [
      ssh: Map.get(config, :keep_ssh, false),
      ssl: Map.get(config, :keep_ssl, true),
      http: Map.get(config, :keep_http, false),
      mnesia: Map.get(config, :keep_mnesia, false),
      dev_tools: Map.get(config, :keep_dev_tools, false)
    ]
  end
  
  @doc """
  Generate OTP stripping commands for shell scripts.
  """
  def otp_strip_commands(config) do
    if config.strip_modules do
      opts = get_otp_strip_opts(config)
      OTPStripper.shell_commands(opts)
    else
      ""
    end
  end
  
  @doc """
  Generate OTP stripping commands for Dockerfiles.
  """
  def otp_strip_dockerfile(config) do
    if config.strip_modules do
      opts = get_otp_strip_opts(config)
      OTPStripper.dockerfile_commands(opts)
    else
      ""
    end
  end
  
  @doc """
  Check for required dependencies and return descriptive errors.
  """
  def check_dependencies(deps) when is_list(deps) do
    missing = Enum.filter(deps, fn dep ->
      !Utils.command_available?(dep)
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required dependencies: #{Enum.join(missing, ", ")}"}
    end
  end
  
  @doc """
  Validate builder-specific configuration.
  """
  def validate_config(config, required_fields) do
    missing = Enum.filter(required_fields, fn field ->
      is_nil(Map.get(config, field))
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required configuration: #{Enum.join(missing, ", ")}"}
    end
  end
  
  @doc """
  Create a temporary build directory with cleanup.
  """
  def with_temp_dir(prefix, fun) do
    temp_dir = Path.join(System.tmp_dir!(), "#{prefix}_#{:os.system_time()}")
    Utils.ensure_clean_dir(temp_dir)
    
    try do
      fun.(temp_dir)
    after
      File.rm_rf(temp_dir)
    end
  end
  
  @doc """
  Standard error handling macro for build pipelines.
  """
  defmacro with_error_handling(do: block) do
    quote do
      try do
        unquote(block)
      rescue
        e in RuntimeError ->
          {:error, Exception.message(e)}
        e ->
          {:error, "Unexpected error: #{inspect(e)}"}
      end
    end
  end
  
  @doc """
  Report build progress.
  """
  def report_progress(message, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "==>")
    IO.puts("#{prefix} #{message}")
  end
  
  @doc """
  Format size for display.
  """
  def format_size(bytes) when is_integer(bytes) do
    mb = bytes / 1_048_576
    "#{Float.round(mb, 2)} MB"
  end
  def format_size(mb) when is_float(mb) do
    "#{Float.round(mb, 2)} MB"
  end
end