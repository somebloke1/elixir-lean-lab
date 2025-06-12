defmodule ElixirLeanLab.Builder.Common do
  @moduledoc """
  Common utilities and patterns extracted from all builders.
  Reduces duplication and ensures consistency across builder implementations.
  """
  
  require Logger
  
  @doc """
  Calculates file or directory size in MB.
  """
  def get_size_mb(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> 
        Float.round(size / 1_048_576, 2)
        
      {:error, _} ->
        # Try du for directories
        case System.cmd("du", ["-sb", path], stderr_to_stdout: true) do
          {output, 0} ->
            [size_str | _] = String.split(output, "\t")
            size = String.to_integer(String.trim(size_str))
            Float.round(size / 1_048_576, 2)
            
          _ -> 
            0.0
        end
    end
  end
  
  @doc """
  Downloads a file with progress reporting.
  """
  def download_file(url, destination, opts \\ []) do
    show_progress = Keyword.get(opts, :show_progress, true)
    
    # Create parent directory if needed
    File.mkdir_p!(Path.dirname(destination))
    
    # Use wget with progress bar if requested
    wget_args = if show_progress do
      ["-O", destination, url]
    else
      ["-q", "-O", destination, url]
    end
    
    case System.cmd("wget", wget_args, stderr_to_stdout: true) do
      {_, 0} -> 
        {:ok, destination}
        
      {output, _} ->
        # Try curl as fallback
        curl_args = if show_progress do
          ["-L", "-o", destination, url]
        else
          ["-s", "-L", "-o", destination, url]
        end
        
        case System.cmd("curl", curl_args, stderr_to_stdout: true) do
          {_, 0} -> 
            {:ok, destination}
            
          {curl_output, _} ->
            {:error, "Download failed with wget: #{output}, curl: #{curl_output}"}
        end
    end
  end
  
  @doc """
  Extracts archives with automatic format detection.
  """
  def extract_archive(archive_path, destination) do
    File.mkdir_p!(destination)
    
    cond do
      String.ends_with?(archive_path, ".tar.xz") ->
        System.cmd("tar", ["-xJf", archive_path, "-C", destination])
        
      String.ends_with?(archive_path, ".tar.gz") ->
        System.cmd("tar", ["-xzf", archive_path, "-C", destination])
        
      String.ends_with?(archive_path, ".tar.bz2") ->
        System.cmd("tar", ["-xjf", archive_path, "-C", destination])
        
      String.ends_with?(archive_path, ".tar") ->
        System.cmd("tar", ["-xf", archive_path, "-C", destination])
        
      String.ends_with?(archive_path, ".zip") ->
        System.cmd("unzip", ["-q", archive_path, "-d", destination])
        
      true ->
        {:error, "Unknown archive format: #{Path.extname(archive_path)}"}
    end
    |> case do
      {_, 0} -> {:ok, destination}
      {output, _} -> {:error, "Extraction failed: #{output}"}
    end
  end
  
  @doc """
  Strips binaries and libraries to reduce size.
  """
  def strip_binaries(directory) do
    # Find all ELF executables and libraries
    {files, 0} = System.cmd("find", [
      directory,
      "-type", "f",
      "(", "-executable", "-o", "-name", "*.so*", ")",
      "-exec", "file", "{}", ";"
    ])
    
    files
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "ELF"))
    |> Enum.map(fn line ->
      [path | _] = String.split(line, ":")
      path
    end)
    |> Enum.each(fn file ->
      # Strip with appropriate flags based on file type
      strip_args = if String.contains?(file, "shared object") do
        ["--strip-unneeded", file]
      else
        ["--strip-all", file]
      end
      
      System.cmd("strip", strip_args, stderr_to_stdout: true)
    end)
    
    :ok
  end
  
  @doc """
  Removes common unnecessary files to reduce image size.
  """
  def cleanup_unnecessary_files(root_dir) do
    patterns_to_remove = [
      "**/*.a",           # Static libraries
      "**/*.la",          # Libtool archives
      "**/man/**",        # Man pages
      "**/doc/**",        # Documentation
      "**/info/**",       # Info pages
      "**/examples/**",   # Examples
      "**/include/**",    # Header files (unless needed)
      "**/*.pyc",         # Python bytecode
      "**/*.pyo",         # Python optimized bytecode
      "**/__pycache__/**", # Python cache directories
      "**/test/**",       # Test files
      "**/tests/**",      # Test files
      "**/.git/**",       # Git directories
      "**/README*",       # README files
      "**/LICENSE*",      # License files (keep one copy)
      "**/CHANGELOG*",    # Changelog files
      "**/AUTHORS*",      # Author files
    ]
    
    Enum.each(patterns_to_remove, fn pattern ->
      paths = Path.wildcard(Path.join(root_dir, pattern))
      Enum.each(paths, &File.rm_rf/1)
    end)
    
    :ok
  end
  
  @doc """
  Compresses a directory into an archive with maximum compression.
  """
  def compress_directory(source_dir, output_path, format \\ :xz) do
    tar_args = case format do
      :xz -> ["-cJf", output_path, "-C", Path.dirname(source_dir), Path.basename(source_dir)]
      :gz -> ["-czf", output_path, "-C", Path.dirname(source_dir), Path.basename(source_dir)]
      :bz2 -> ["-cjf", output_path, "-C", Path.dirname(source_dir), Path.basename(source_dir)]
      _ -> ["-cf", output_path, "-C", Path.dirname(source_dir), Path.basename(source_dir)]
    end
    
    # Add compression level for xz
    env = if format == :xz do
      [{"XZ_OPT", "-9"}]
    else
      []
    end
    
    case System.cmd("tar", tar_args, env: env) do
      {_, 0} -> {:ok, output_path}
      {output, _} -> {:error, "Compression failed: #{output}"}
    end
  end
  
  @doc """
  Executes a command with proper error handling and logging.
  """
  def exec_cmd(command, args, opts \\ []) do
    working_dir = Keyword.get(opts, :cd)
    env = Keyword.get(opts, :env, [])
    log_output = Keyword.get(opts, :log_output, false)
    
    cmd_opts = [stderr_to_stdout: true]
    cmd_opts = if working_dir, do: [{:cd, working_dir} | cmd_opts], else: cmd_opts
    cmd_opts = if length(env) > 0, do: [{:env, env} | cmd_opts], else: cmd_opts
    
    if log_output do
      Logger.info("Executing: #{command} #{Enum.join(args, " ")}")
    end
    
    case System.cmd(command, args, cmd_opts) do
      {output, 0} -> 
        if log_output && String.trim(output) != "" do
          Logger.debug("Command output: #{output}")
        end
        {:ok, output}
        
      {output, exit_code} ->
        Logger.error("Command failed with exit code #{exit_code}: #{command} #{Enum.join(args, " ")}")
        Logger.error("Output: #{output}")
        {:error, {exit_code, output}}
    end
  end
  
  @doc """
  Creates a temporary working directory that's automatically cleaned up.
  """
  def with_temp_dir(prefix, fun) do
    temp_dir = Path.join(System.tmp_dir!(), "#{prefix}-#{:os.system_time()}")
    File.mkdir_p!(temp_dir)
    
    try do
      fun.(temp_dir)
    after
      File.rm_rf!(temp_dir)
    end
  end
  
  @doc """
  Validates that required tools are available.
  """
  def ensure_tools_available(tools) do
    missing = Enum.filter(tools, fn tool ->
      System.find_executable(tool) == nil
    end)
    
    case missing do
      [] -> :ok
      tools -> {:error, "Missing required tools: #{Enum.join(tools, ", ")}"}
    end
  end
  
  @doc """
  Generates a build report with consistent format across all builders.
  """
  def generate_build_report(image_path, type, artifacts \\ %{}, metadata \\ %{}) do
    base_report = %{
      image: image_path,
      type: type,
      size_mb: get_size_mb(image_path),
      artifacts: artifacts,
      timestamp: DateTime.utc_now(),
      build_host: :inet.gethostname() |> elem(1) |> to_string()
    }
    
    Map.merge(base_report, metadata)
  end
  
  @doc """
  Packages multiple files into a single distributable archive.
  """
  def package_files(files, output_path, opts \\ []) do
    format = Keyword.get(opts, :format, :tar_xz)
    base_dir = Keyword.get(opts, :base_dir)
    
    with_temp_dir("package", fn temp_dir ->
      # Copy files to temp directory
      Enum.each(files, fn {src, dest} ->
        dest_path = if base_dir do
          Path.join([temp_dir, base_dir, dest])
        else
          Path.join(temp_dir, dest)
        end
        
        File.mkdir_p!(Path.dirname(dest_path))
        File.cp!(src, dest_path)
      end)
      
      # Create archive
      case format do
        :tar_xz ->
          compress_directory(temp_dir, output_path, :xz)
          
        :tar_gz ->
          compress_directory(temp_dir, output_path, :gz)
          
        :zip ->
          case System.cmd("zip", ["-r", output_path, "."], cd: temp_dir) do
            {_, 0} -> {:ok, output_path}
            {output, _} -> {:error, "Zip creation failed: #{output}"}
          end
          
        _ ->
          {:error, "Unknown package format: #{format}"}
      end
    end)
  end
end