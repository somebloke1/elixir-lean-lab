defmodule ElixirLeanLab.Builder.Utils do
  @moduledoc """
  Common utilities for VM builders.
  
  This module provides low-level utilities used across different builders:
  - File operations (size calculation, compression)
  - System command execution
  - Download and extraction
  - Directory management
  """
  
  @doc """
  Get file size in megabytes.
  """
  def get_file_size_mb(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> Float.round(size / 1_048_576, 2)
      _ -> 0.0
    end
  end
  
  @doc """
  Execute a system command with proper error handling.
  
  Returns {:ok, output} on success or {:error, reason} on failure.
  """
  def exec(command, args, opts \\ []) do
    merged_opts = Keyword.merge([stderr_to_stdout: true], opts)
    
    case System.cmd(command, args, merged_opts) do
      {output, 0} -> 
        {:ok, output}
      {output, exit_code} ->
        reason = format_error(command, args, output, exit_code)
        {:error, reason}
    end
  end
  
  @doc """
  Execute a system command and raise on failure.
  """
  def exec!(command, args, opts \\ []) do
    case exec(command, args, opts) do
      {:ok, output} -> output
      {:error, reason} -> raise reason
    end
  end
  
  defp format_error(command, args, output, exit_code) do
    cmd_str = Enum.join([command | args], " ")
    """
    Command failed with exit code #{exit_code}:
    Command: #{cmd_str}
    Output: #{String.trim(output)}
    """
  end
  
  @doc """
  Download a file using wget or curl.
  """
  def download_file(url, dest_path, opts \\ []) do
    dir = Path.dirname(dest_path)
    File.mkdir_p!(dir)
    
    cond do
      command_available?("wget") ->
        exec("wget", ["-O", dest_path, url], cd: dir)
      
      command_available?("curl") ->
        exec("curl", ["-L", "-o", dest_path, url], cd: dir)
      
      true ->
        {:error, "Neither wget nor curl is available"}
    end
  end
  
  @doc """
  Extract a tar archive.
  """
  def extract_archive(archive_path, dest_dir, opts \\ []) do
    File.mkdir_p!(dest_dir)
    
    tar_opts = case Path.extname(archive_path) do
      ".xz" -> ["-xJf"]
      ".gz" -> ["-xzf"]
      ".bz2" -> ["-xjf"]
      _ -> ["-xf"]
    end
    
    strip_components = Keyword.get(opts, :strip_components, 0)
    tar_args = if strip_components > 0 do
      tar_opts ++ [archive_path, "--strip-components=#{strip_components}"]
    else
      tar_opts ++ [archive_path]
    end
    
    exec("tar", tar_args, cd: dest_dir)
  end
  
  @doc """
  Compress a file using the specified method.
  """
  def compress_file(path, method, opts \\ []) do
    level = Keyword.get(opts, :level, 9)
    keep_original = Keyword.get(opts, :keep_original, false)
    
    {command, args, ext} = case method do
      :xz -> {"xz", ["-#{level}"] ++ if(keep_original, do: ["-k"], else: []), ".xz"}
      :gzip -> {"gzip", ["-#{level}"] ++ if(keep_original, do: ["-k"], else: []), ".gz"}
      :bzip2 -> {"bzip2", ["-#{level}"] ++ if(keep_original, do: ["-k"], else: []), ".bz2"}
      _ -> {nil, nil, nil}
    end
    
    if command do
      case exec(command, args ++ [path]) do
        {:ok, _} -> {:ok, path <> ext}
        error -> error
      end
    else
      {:ok, path}
    end
  end
  
  @doc """
  Create a tar archive from a directory or list of files.
  """
  def create_tar_archive(files, archive_path, opts \\ []) do
    compression = Keyword.get(opts, :compression, :none)
    base_dir = Keyword.get(opts, :cd)
    
    tar_opts = case compression do
      :xz -> ["-cJf"]
      :gzip -> ["-czf"]
      :bzip2 -> ["-cjf"]
      _ -> ["-cf"]
    end
    
    file_list = if is_list(files), do: files, else: [files]
    args = tar_opts ++ [archive_path] ++ file_list
    
    if base_dir do
      exec("tar", args, cd: base_dir)
    else
      exec("tar", args)
    end
  end
  
  @doc """
  Check if a command is available in PATH.
  """
  def command_available?(command) do
    case System.cmd("which", [command], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end
  
  @doc """
  Ensure a directory exists and is clean.
  """
  def ensure_clean_dir(path) do
    if File.exists?(path) do
      File.rm_rf!(path)
    end
    File.mkdir_p!(path)
    path
  end
  
  @doc """
  Copy files or directories recursively.
  """
  def copy_recursive(source, dest) do
    case File.cp_r(source, dest) do
      {:ok, _} -> :ok
      {:error, reason, _} -> {:error, "Failed to copy #{source} to #{dest}: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Make a file executable.
  """
  def make_executable(path) do
    case File.chmod(path, 0o755) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to make #{path} executable: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Write content to a file and optionally make it executable.
  """
  def write_file(path, content, opts \\ []) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
    
    case File.write(path, content) do
      :ok ->
        if Keyword.get(opts, :executable, false) do
          make_executable(path)
        else
          :ok
        end
      {:error, reason} ->
        {:error, "Failed to write #{path}: #{inspect(reason)}"}
    end
  end
  
  defmodule Docker do
    @moduledoc """
    Docker-specific utilities.
    """
    
    alias ElixirLeanLab.Builder.Utils
    
    @doc """
    Build a Docker image.
    """
    def build(dockerfile_path, context_dir, tag) do
      Utils.exec("docker", ["build", "-t", tag, "-f", dockerfile_path, context_dir])
    end
    
    @doc """
    Save a Docker image to a tar file.
    """
    def save(image_name, output_path) do
      Utils.exec("docker", ["save", "-o", output_path, image_name])
    end
    
    @doc """
    Check if Docker is available.
    """
    def available? do
      Utils.command_available?("docker")
    end
    
    @doc """
    Run a Docker container and execute commands.
    """
    def run(image, commands, opts \\ []) do
      args = ["run", "--rm"] ++ 
             if(opts[:interactive], do: ["-it"], else: []) ++
             Enum.flat_map(opts[:volumes] || [], fn {host, container} ->
               ["-v", "#{host}:#{container}"]
             end) ++
             Enum.flat_map(opts[:env] || [], fn {key, value} ->
               ["-e", "#{key}=#{value}"]
             end) ++
             [image] ++ commands
      
      Utils.exec("docker", args)
    end
  end
end