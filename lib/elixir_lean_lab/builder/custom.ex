defmodule ElixirLeanLab.Builder.Custom do
  @moduledoc """
  Custom kernel and filesystem builder for ultimate control.
  
  This builder provides:
  - Custom Linux kernel compilation
  - Minimal initramfs creation
  - Direct BEAM integration
  - Sub-20MB target sizes
  """

  alias ElixirLeanLab.{Builder, Config, KernelConfig, OTPStripper}
  alias ElixirLeanLab.Builder.{Common, Utils}

  @kernel_version "6.6.70"
  @busybox_version "1.36.1"

  def build(%Config{} = config) do
    with {:ok, build_dir} <- Builder.prepare_build_env(config),
         {:ok, app_dir} <- Builder.prepare_app(config.app_path, build_dir),
         {:ok, kernel_path} <- build_custom_kernel(build_dir, config),
         {:ok, initramfs_path} <- build_minimal_initramfs(build_dir, app_dir, config),
         {:ok, vm_image} <- package_custom_vm(kernel_path, initramfs_path, config) do
      
      Builder.report_size(vm_image)
      Common.build_result(vm_image, :custom, %{
        kernel: kernel_path,
        initramfs: initramfs_path
      })
    end
  end

  defp build_custom_kernel(build_dir, config) do
    Common.with_error_handling do
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-#{@kernel_version}.tar.xz"
      {:ok, kernel_dir} = Common.download_and_extract(url, "linux", @kernel_version, build_dir)
    
    # Configure kernel
    case configure_custom_kernel(kernel_dir, config) do
      :ok ->
        # Build kernel
        case System.cmd("make", ["-j#{System.schedulers()}"], cd: kernel_dir) do
          {_, 0} ->
            kernel_path = Path.join([kernel_dir, "arch", "x86", "boot", "bzImage"])
            {:ok, kernel_path}
          {output, _} ->
            {:error, "Kernel build failed: #{output}"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  catch
    {:error, reason} -> {:error, reason}
  end

  defp configure_custom_kernel(kernel_dir, config) do
    # Create kernel configuration
    kernel_config = KernelConfig.qemu_minimal()
    config_content = generate_kernel_config(kernel_config, config)
    
    config_path = Path.join(kernel_dir, ".config")
    
    with :ok <- File.write(config_path, config_content) do
      # Apply configuration
      case System.cmd("make", ["olddefconfig"], cd: kernel_dir) do
        {_, 0} -> :ok
        {output, _} -> {:error, "Kernel config failed: #{output}"}
      end
    else
      {:error, reason} -> {:error, "Failed to write kernel config: #{inspect(reason)}"}
    end
  end

  defp generate_kernel_config(kernel_config, config) do
    base_config = """
    # Custom minimal kernel configuration for Elixir VM
    # Target size: #{config.target_size}MB
    
    # Base configuration
    CONFIG_64BIT=y
    CONFIG_SMP=y
    CONFIG_LOCALVERSION="-elixir-vm"
    
    # Essential features
    #{kernel_config.enable |> Enum.join("\n")}
    
    # Built-in initramfs
    CONFIG_INITRAMFS_SOURCE="initramfs.cpio"
    CONFIG_INITRAMFS_COMPRESSION_XZ=y
    
    # Size optimizations
    CONFIG_CC_OPTIMIZE_FOR_SIZE=y
    CONFIG_SLOB=y
    CONFIG_KERNEL_XZ=y
    
    # Disabled features
    #{kernel_config.disable |> Enum.map(&"# #{&1} is not set") |> Enum.join("\n")}
    
    # Additional size optimizations
    # CONFIG_DEBUG_INFO is not set
    # CONFIG_DEBUG_KERNEL is not set
    # CONFIG_KALLSYMS is not set
    # CONFIG_BUG is not set
    # CONFIG_ELF_CORE is not set
    # CONFIG_BASE_FULL is not set
    # CONFIG_FUTEX is not set
    # CONFIG_EPOLL is not set
    # CONFIG_SIGNALFD is not set
    # CONFIG_TIMERFD is not set
    # CONFIG_EVENTFD is not set
    # CONFIG_AIO is not set
    """
    
    base_config
  end

  defp build_minimal_initramfs(build_dir, app_dir, config) do
    initramfs_dir = Path.join(build_dir, "initramfs")
    
    with :ok <- File.mkdir_p(initramfs_dir) do
    
    with :ok <- build_busybox(build_dir, initramfs_dir),
         :ok <- install_erlang_runtime(build_dir, initramfs_dir, config),
         :ok <- install_elixir_app(app_dir, initramfs_dir, config),
         :ok <- create_init_script(initramfs_dir, config),
         {:ok, cpio_path} <- create_initramfs_cpio(initramfs_dir, build_dir) do
        {:ok, cpio_path}
      end
    end
  end

  defp build_busybox(build_dir, initramfs_dir) do
    Common.with_error_handling do
      url = "https://busybox.net/downloads/busybox-#{@busybox_version}.tar.bz2"
      {:ok, busybox_dir} = Common.download_and_extract(url, "busybox", @busybox_version, build_dir)
    
    # Configure BusyBox for minimal build
    case System.cmd("make", ["defconfig"], cd: busybox_dir) do
      {_, 0} ->
        # Enable static linking
        config_path = Path.join(busybox_dir, ".config")
        with {:ok, config_content} <- File.read(config_path),
             modified_config = String.replace(config_content, "# CONFIG_STATIC is not set", "CONFIG_STATIC=y"),
             :ok <- File.write(config_path, modified_config) do
        
          # Build BusyBox
          case System.cmd("make", ["-j#{System.schedulers()}"], cd: busybox_dir) do
            {_, 0} ->
            # Install to initramfs
            case System.cmd("make", ["CONFIG_PREFIX=#{initramfs_dir}", "install"], cd: busybox_dir) do
                {_, 0} -> :ok
                {output, _} -> {:error, "BusyBox install failed: #{output}"}
              end
            {output, _} ->
              {:error, "BusyBox build failed: #{output}"}
          end
        else
          {:error, reason} -> {:error, "BusyBox config failed: #{inspect(reason)}"}
        end
      {output, _} ->
        {:error, "BusyBox config failed: #{output}"}
    end
  catch
    {:error, reason} -> {:error, reason}
  end

  defp install_erlang_runtime(build_dir, initramfs_dir, config) do
    # Create a minimal Erlang installation using Docker
    # This extracts just the BEAM runtime from an Alpine container
    
    erlang_script = Path.join(build_dir, "extract_erlang.sh")
    
    script_content = """
    #!/bin/bash
    set -e
    
    # Create temp container with Erlang
    docker run --name erlang_extract --detach alpine:3.19 sleep 30
    docker exec erlang_extract apk add --no-cache erlang erlang-dev
    
    # Extract BEAM runtime
    docker cp erlang_extract:/usr/lib/erlang #{initramfs_dir}/usr/lib/erlang
    docker cp erlang_extract:/usr/bin/erl #{initramfs_dir}/bin/erl
    docker cp erlang_extract:/usr/bin/erlc #{initramfs_dir}/bin/erlc
    
    # Clean up
    docker stop erlang_extract
    docker rm erlang_extract
    
    # Strip runtime if configured
    if [ "#{config.strip_modules}" = "true" ]; then
        echo "Stripping Erlang runtime..."
        #{generate_strip_commands(config)}
    fi
    
    echo "Erlang runtime installed"
    """
    
    with :ok <- File.write(erlang_script, script_content),
         :ok <- File.chmod(erlang_script, 0o755) do
    
      case System.cmd("bash", [erlang_script], cd: build_dir) do
        {_, 0} -> :ok
        {output, _} -> {:error, "Erlang extraction failed: #{output}"}
      end
    else
      {:error, reason} -> {:error, "Failed to create Erlang script: #{inspect(reason)}"}
    end
  end

  defp generate_strip_commands(config) do
    otp_opts = Common.get_otp_strip_config(config)
    OTPStripper.shell_commands(otp_opts)
  end

  defp install_elixir_app(nil, initramfs_dir, _config) do
    # No app to install, just create a minimal IEx setup
    create_minimal_elixir_setup(initramfs_dir)
  end
  defp install_elixir_app(app_dir, initramfs_dir, config) do
    # Copy compiled app to initramfs
    app_dest = Path.join(initramfs_dir, "opt/app")
    File.mkdir_p!(app_dest)
    
    case File.cp_r(app_dir, app_dest) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Failed to copy app: #{inspect(reason)}"}
    end
  end

  defp create_minimal_elixir_setup(initramfs_dir) do
    # Create a basic Elixir wrapper script
    bin_dir = Path.join(initramfs_dir, "bin")
    
    with :ok <- File.mkdir_p(bin_dir) do
      elixir_script = Path.join(bin_dir, "elixir")
      
      script_content = """
      #!/bin/sh
      export ERL_LIBS="/usr/lib/erlang/lib"
      exec erl -noshell -s elixir start_cli -extra "$@"
      """
      
      with :ok <- File.write(elixir_script, script_content),
           :ok <- File.chmod(elixir_script, 0o755) do
        :ok
      else
        {:error, reason} -> {:error, "Failed to create elixir script: #{inspect(reason)}"}
      end
    else
      {:error, reason} -> {:error, "Failed to create bin directory: #{inspect(reason)}"}
    end
  end

  defp create_init_script(initramfs_dir, config) do
    init_script = Path.join(initramfs_dir, "init")
    
    script_content = """
    #!/bin/sh
    
    # Minimal init script for Elixir VM
    echo "🚀 Starting Custom Elixir VM..."
    
    # Mount essential filesystems
    mount -t proc proc /proc
    mount -t sysfs sysfs /sys
    mount -t devtmpfs devtmpfs /dev
    
    # Set up environment
    export PATH="/bin:/sbin:/usr/bin:/usr/sbin"
    export HOME="/root"
    export ERL_LIBS="/usr/lib/erlang/lib"
    
    # Print system info
    echo "Kernel: $(uname -r)"
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
    
    #{if config.app_path do
      "# Start application\ncd /opt/app && exec ./start"
    else
      "# Start Elixir shell\nexec /bin/elixir -S iex"
    end}
    """
    
    with :ok <- File.write(init_script, script_content),
         :ok <- File.chmod(init_script, 0o755) do
      :ok
    else
      {:error, reason} -> {:error, "Failed to create init script: #{inspect(reason)}"}
    end
  end

  defp create_initramfs_cpio(initramfs_dir, build_dir) do
    cpio_path = Path.join(build_dir, "initramfs.cpio")
    
    # Create CPIO archive
    case System.cmd("find", [".", "-print0"], cd: initramfs_dir) do
      {file_list, 0} ->
        case System.cmd("cpio", ["-o", "-H", "newc", "-0"], 
                        input: file_list, cd: initramfs_dir) do
          {cpio_data, 0} ->
            File.write!(cpio_path, cpio_data)
            
            # Compress with XZ
            compressed_path = cpio_path <> ".xz"
            case System.cmd("xz", ["-9", "-c", cpio_path]) do
              {compressed_data, 0} ->
                case File.write(compressed_path, compressed_data) do
                  :ok -> {:ok, compressed_path}
                  {:error, reason} -> {:error, "Failed to write compressed file: #{inspect(reason)}"}
                end
              {output, _} ->
                {:error, "CPIO compression failed: #{output}"}
            end
          
          {output, _} ->
            {:error, "CPIO creation failed: #{output}"}
        end
      
      {output, _} ->
        {:error, "File listing failed: #{output}"}
    end
  end

  defp package_custom_vm(kernel_path, initramfs_path, config) do
    vm_name = "custom-vm.tar.xz"
    vm_path = Path.join(config.output_dir, vm_name)
    
    Common.package_vm([kernel_path, initramfs_path], vm_path,
                      compression: :xz,
                      base_dir: Path.dirname(kernel_path))
  end

  @doc """
  Check for required build tools.
  """
  def validate_dependencies do
    Common.check_dependencies(["wget", "tar", "make", "gcc", "docker"])
  end

  @doc """
  Estimate final VM size based on configuration.
  """
  def estimate_size(config) do
    kernel_size = 2  # ~2MB kernel
    busybox_size = 1  # ~1MB static BusyBox
    erlang_size = if config.strip_modules, do: 8, else: 15  # 8-15MB BEAM
    app_size = if config.app_path, do: 3, else: 0  # ~3MB app
    
    total = kernel_size + busybox_size + erlang_size + app_size
    "#{total}-#{total + 5}MB"
  end
end