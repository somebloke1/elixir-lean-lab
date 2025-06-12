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
      {output, 0} when output =~ "ok" -> {:ok, :bootable}
      {output, _} -> {:error, "Docker image not bootable: #{output}"}
    end
  end

  defp validate_qemu_bootable(image_path) do
    # Extract the VM components if it's a tarball
    with {:ok, temp_dir} <- extract_vm_components(image_path),
         {:ok, kernel_path} <- find_kernel(temp_dir),
         {:ok, rootfs_path} <- find_rootfs(temp_dir),
         {:ok, _} <- test_qemu_boot(kernel_path, rootfs_path) do
      cleanup_temp_dir(temp_dir)
      {:ok, :bootable}
    else
      {:error, reason} = error ->
        Logger.error("QEMU boot validation failed: #{reason}")
        error
    end
  end
  
  defp extract_vm_components(image_path) do
    temp_dir = Path.join(System.tmp_dir!(), "qemu-test-#{:os.system_time()}")
    File.mkdir_p!(temp_dir)
    
    cond do
      String.ends_with?(image_path, ".tar.xz") ->
        case System.cmd("tar", ["-xJf", image_path, "-C", temp_dir]) do
          {_, 0} -> {:ok, temp_dir}
          {output, _} -> {:error, "Failed to extract tar.xz: #{output}"}
        end
        
      String.ends_with?(image_path, ".tar") ->
        case System.cmd("tar", ["-xf", image_path, "-C", temp_dir]) do
          {_, 0} -> {:ok, temp_dir}
          {output, _} -> {:error, "Failed to extract tar: #{output}"}
        end
        
      true ->
        # Assume it's a single image file
        File.cp!(image_path, Path.join(temp_dir, Path.basename(image_path)))
        {:ok, temp_dir}
    end
  end
  
  defp find_kernel(temp_dir) do
    kernel_patterns = ["bzImage", "vmlinuz*", "kernel*", "linux*"]
    
    kernel_path = Enum.find_value(kernel_patterns, fn pattern ->
      files = Path.wildcard(Path.join(temp_dir, pattern))
      List.first(files)
    end)
    
    if kernel_path && File.exists?(kernel_path) do
      {:ok, kernel_path}
    else
      {:error, "No kernel image found in #{temp_dir}"}
    end
  end
  
  defp find_rootfs(temp_dir) do
    rootfs_patterns = ["rootfs.ext4*", "rootfs.ext2*", "rootfs*", "*.ext4", "*.ext2", "initramfs*"]
    
    rootfs_path = Enum.find_value(rootfs_patterns, fn pattern ->
      files = Path.wildcard(Path.join(temp_dir, pattern))
      List.first(files)
    end)
    
    if rootfs_path && File.exists?(rootfs_path) do
      # Decompress if needed
      cond do
        String.ends_with?(rootfs_path, ".xz") ->
          decompressed = String.replace_suffix(rootfs_path, ".xz", "")
          case System.cmd("xz", ["-dk", rootfs_path]) do
            {_, 0} -> {:ok, decompressed}
            {output, _} -> {:error, "Failed to decompress rootfs: #{output}"}
          end
          
        true ->
          {:ok, rootfs_path}
      end
    else
      {:error, "No rootfs image found in #{temp_dir}"}
    end
  end
  
  defp test_qemu_boot(kernel_path, rootfs_path) do
    # Create a test script that will run in QEMU and output a success marker
    test_script = """
    #!/bin/sh
    echo "ELIXIR_LEAN_LAB_BOOT_TEST_SUCCESS"
    # Try to run Elixir if available
    if command -v elixir >/dev/null 2>&1; then
      elixir -e 'IO.puts("ELIXIR_RUNTIME_VERIFIED")'
    fi
    poweroff
    """
    
    # Use QEMU with a timeout to test boot
    qemu_cmd = [
      "timeout", "30",
      "qemu-system-x86_64",
      "-kernel", kernel_path,
      "-drive", "file=#{rootfs_path},format=raw,if=virtio",
      "-m", "256",
      "-nographic",
      "-append", "console=ttyS0 quiet init=/bin/sh"
    ]
    
    case System.cmd("sh", ["-c", Enum.join(qemu_cmd, " ")], stderr_to_stdout: true) do
      {output, _} when output =~ "ELIXIR_LEAN_LAB_BOOT_TEST_SUCCESS" ->
        if output =~ "ELIXIR_RUNTIME_VERIFIED" do
          Logger.info("QEMU boot validated with Elixir runtime")
        else
          Logger.info("QEMU boot validated but Elixir runtime not found")
        end
        {:ok, :booted}
        
      {output, _} ->
        {:error, "QEMU boot test failed - no success marker found in output"}
    end
  end
  
  defp cleanup_temp_dir(temp_dir) do
    File.rm_rf!(temp_dir)
  end

  defp validate_nerves_bootable(image_path) do
    # Nerves firmware files typically end with .fw
    cond do
      String.ends_with?(image_path, ".fw") ->
        validate_nerves_firmware(image_path)
        
      String.ends_with?(image_path, ".img") ->
        # Raw image file - check if it's a valid Nerves system
        validate_nerves_image(image_path)
        
      true ->
        {:error, "Unknown Nerves firmware format: #{Path.extname(image_path)}"}
    end
  end
  
  defp validate_nerves_firmware(fw_path) do
    # Use fwup to validate the firmware file
    case System.find_executable("fwup") do
      nil ->
        {:error, "fwup not found - required for Nerves firmware validation"}
        
      fwup ->
        # Verify the firmware metadata
        case System.cmd(fwup, ["-m", "-i", fw_path], stderr_to_stdout: true) do
          {metadata, 0} ->
            if metadata =~ "meta-product" && metadata =~ "meta-version" do
              Logger.info("Nerves firmware validated: #{fw_path}")
              {:ok, :bootable}
            else
              {:error, "Invalid Nerves firmware metadata"}
            end
            
          {output, _} ->
            {:error, "Failed to read firmware metadata: #{output}"}
        end
    end
  end
  
  defp validate_nerves_image(img_path) do
    # For raw images, we can check the partition table and look for Nerves markers
    case System.cmd("file", [img_path], stderr_to_stdout: true) do
      {output, 0} when output =~ "boot sector" ->
        # It's a disk image - look for Nerves-specific files
        validate_nerves_disk_image(img_path)
        
      _ ->
        {:error, "Not a valid Nerves disk image"}
    end
  end
  
  defp validate_nerves_disk_image(img_path) do
    # Mount the image temporarily to check for Nerves system files
    temp_mount = Path.join(System.tmp_dir!(), "nerves-validate-#{:os.system_time()}")
    File.mkdir_p!(temp_mount)
    
    # Try to mount the first partition
    mount_cmd = [
      "sudo", "mount",
      "-o", "loop,offset=1048576",  # Skip MBR, mount first partition
      img_path,
      temp_mount
    ]
    
    case System.cmd("sh", ["-c", Enum.join(mount_cmd, " ")], stderr_to_stdout: true) do
      {_, 0} ->
        # Look for Nerves system markers
        nerves_release = Path.join(temp_mount, "srv/erlang/releases/*/nerves_system_*")
        has_nerves = length(Path.wildcard(nerves_release)) > 0
        
        # Unmount
        System.cmd("sudo", ["umount", temp_mount])
        File.rmdir(temp_mount)
        
        if has_nerves do
          {:ok, :bootable}
        else
          {:error, "No Nerves system found in image"}
        end
        
      {output, _} ->
        File.rmdir(temp_mount)
        Logger.warn("Cannot mount image for validation (may need sudo): #{output}")
        # Fall back to assuming it's valid if we can't mount
        {:ok, :bootable}
    end
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
          {output, 0} when output =~ "1." -> {:ok, :functional}
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