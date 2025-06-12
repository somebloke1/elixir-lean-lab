defmodule ElixirLeanLab.VM do
  @moduledoc """
  VM management for testing and analyzing minimal Elixir VMs.
  """

  @doc """
  Launch a VM image using QEMU.
  """
  def launch(image_path, opts \\ []) do
    memory = opts[:memory] || 256
    cpus = opts[:cpus] || 1
    
    cond do
      String.ends_with?(image_path, ".tar") or String.ends_with?(image_path, ".tar.xz") ->
        launch_docker_vm(image_path, opts)
      
      String.ends_with?(image_path, ".img") or String.ends_with?(image_path, ".qcow2") ->
        launch_qemu_vm(image_path, memory, cpus)
      
      true ->
        {:error, "Unknown image format: #{Path.extname(image_path)}"}
    end
  end

  @doc """
  Analyze a VM image for size breakdown.
  """
  def analyze(image_path) do
    cond do
      String.ends_with?(image_path, ".tar") ->
        analyze_docker_image(image_path)
      
      String.ends_with?(image_path, ".tar.xz") ->
        # Decompress first
        tar_path = String.replace_suffix(image_path, ".xz", "")
        System.cmd("xz", ["-dk", image_path])
        result = analyze_docker_image(tar_path)
        File.rm(tar_path)
        result
      
      true ->
        analyze_generic_image(image_path)
    end
  end

  defp launch_docker_vm(tar_path, opts) do
    # Load the image into Docker
    image_name = "elixir-lean-vm-test:#{:os.system_time(:second)}"
    
    case System.cmd("docker", ["load", "-i", tar_path]) do
      {output, 0} ->
        # Extract the loaded image ID/name
        loaded_image = extract_loaded_image(output)
        
        # Tag it with our name
        System.cmd("docker", ["tag", loaded_image, image_name])
        
        # Run the container
        run_args = [
          "run",
          "-it",
          "--rm",
          "-m", "#{opts[:memory] || 256}m",
          "--cpus", "#{opts[:cpus] || 1}",
          image_name
        ]
        
        port = System.find_executable("docker")
        Port.open({:spawn_executable, port}, [:binary, args: run_args])
        
        {:ok, image_name}
      
      {output, _} ->
        {:error, "Failed to load Docker image: #{output}"}
    end
  end

  defp launch_qemu_vm(image_path, memory, cpus) do
    qemu_args = [
      "-m", "#{memory}",
      "-smp", "#{cpus}",
      "-nographic",
      "-drive", "file=#{image_path},format=qcow2",
      "-enable-kvm"
    ]
    
    port = System.find_executable("qemu-system-x86_64")
    
    if port do
      Port.open({:spawn_executable, port}, [:binary, args: qemu_args])
      {:ok, "QEMU VM launched"}
    else
      {:error, "QEMU not found. Please install qemu-system-x86_64"}
    end
  end

  defp analyze_docker_image(tar_path) do
    # Create temp directory for extraction
    temp_dir = Path.join(System.tmp_dir!(), "lean-vm-analyze-#{:os.system_time()}")
    File.mkdir_p!(temp_dir)
    
    try do
      # Extract the tar
      {_, 0} = System.cmd("tar", ["-xf", tar_path, "-C", temp_dir])
      
      # Analyze layer sizes
      layers = analyze_docker_layers(temp_dir)
      
      # Find and analyze the filesystem
      fs_analysis = analyze_filesystem(temp_dir)
      
      %{
        total_size: get_file_size(tar_path),
        layers: layers,
        filesystem: fs_analysis,
        components: analyze_components(fs_analysis)
      }
    after
      File.rm_rf!(temp_dir)
    end
  end

  defp analyze_docker_layers(temp_dir) do
    manifest_path = Path.join(temp_dir, "manifest.json")
    
    if File.exists?(manifest_path) do
      manifest = File.read!(manifest_path) |> Jason.decode!()
      
      Enum.flat_map(manifest, fn entry ->
        entry["Layers"]
        |> Enum.map(fn layer_path ->
          full_path = Path.join(temp_dir, layer_path)
          %{
            path: layer_path,
            size: get_file_size(full_path)
          }
        end)
      end)
    else
      []
    end
  end

  defp analyze_filesystem(temp_dir) do
    # Look for extracted filesystem in layers
    layer_dirs = Path.wildcard(Path.join(temp_dir, "*/layer.tar"))
    
    fs_analysis = Enum.reduce(layer_dirs, %{}, fn layer_tar, acc ->
      layer_temp = Path.join(temp_dir, "layer-#{:os.system_time()}")
      File.mkdir_p!(layer_temp)
      
      {_, 0} = System.cmd("tar", ["-xf", layer_tar, "-C", layer_temp])
      
      # Analyze directories
      analyze_directory_sizes(layer_temp, acc)
    end)
    
    fs_analysis
  end

  defp analyze_directory_sizes(root, acc \\ %{}) do
    File.ls!(root)
    |> Enum.reduce(acc, fn entry, acc ->
      path = Path.join(root, entry)
      
      if File.dir?(path) do
        size = get_directory_size(path)
        key = "/" <> entry
        Map.update(acc, key, size, &(&1 + size))
      else
        acc
      end
    end)
  end

  defp get_directory_size(path) do
    case System.cmd("du", ["-sb", path]) do
      {output, 0} ->
        [size_str | _] = String.split(output, "\t")
        String.to_integer(String.trim(size_str))
      _ ->
        0
    end
  end

  defp analyze_components(fs_analysis) do
    %{
      erlang: Map.get(fs_analysis, "/usr/local/lib/erlang", 0),
      elixir: Map.get(fs_analysis, "/usr/local/lib/elixir", 0),
      system_libs: Map.get(fs_analysis, "/lib", 0) + Map.get(fs_analysis, "/usr/lib", 0),
      binaries: Map.get(fs_analysis, "/bin", 0) + Map.get(fs_analysis, "/usr/bin", 0),
      app: Map.get(fs_analysis, "/app", 0)
    }
    |> Enum.map(fn {k, v} -> {k, format_size(v)} end)
    |> Enum.into(%{})
  end

  defp analyze_generic_image(image_path) do
    %{
      total_size: get_file_size(image_path),
      format: Path.extname(image_path)
    }
  end

  defp extract_loaded_image(docker_output) do
    # Docker load output usually contains "Loaded image: <name>"
    case Regex.run(~r/Loaded image: (.+)/, docker_output) do
      [_, image] -> String.trim(image)
      _ -> 
        # Try to find image ID
        case Regex.run(~r/Loaded image ID: sha256:([a-f0-9]+)/, docker_output) do
          [_, id] -> "sha256:" <> id
          _ -> "unknown"
        end
    end
  end

  defp get_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576 do
    kb = Float.round(bytes / 1024, 1)
    "#{kb} KB"
  end
  defp format_size(bytes) do
    mb = Float.round(bytes / 1_048_576, 1)
    "#{mb} MB"
  end
end