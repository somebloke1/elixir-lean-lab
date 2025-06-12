defmodule ElixirLeanLab.Builder.Buildroot do
  @moduledoc """
  Buildroot-based minimal VM builder.
  
  Uses Buildroot to create custom Linux systems with:
  - Custom kernel configuration
  - Minimal root filesystem
  - musl or uClibc for small size
  - Direct hardware support
  """

  alias ElixirLeanLab.{Builder, Config, KernelConfig}
  alias ElixirLeanLab.Builder.{Common, Utils}

  @buildroot_version "2024.02.1"
  @erlang_otp_version "26.2.1"
  @elixir_version "1.15.7"

  def build(%Config{} = config) do
    with {:ok, build_dir} <- Builder.prepare_build_env(config),
         {:ok, app_dir} <- Builder.prepare_app(config.app_path, build_dir),
         {:ok, buildroot_dir} <- download_buildroot(build_dir),
         {:ok, defconfig_path} <- create_defconfig(config, buildroot_dir),
         {:ok, _} <- configure_buildroot(buildroot_dir, defconfig_path),
         {:ok, artifacts} <- build_buildroot(buildroot_dir, config),
         {:ok, vm_image} <- package_vm_image(artifacts, config) do
      
      Builder.report_size(vm_image)
      Common.build_result(vm_image, :buildroot, %{artifacts: artifacts})
    end
  end

  defp download_buildroot(build_dir) do
    url = "https://buildroot.org/downloads/buildroot-#{@buildroot_version}.tar.xz"
    Common.download_and_extract(url, "buildroot", @buildroot_version, build_dir)
  end

  defp create_defconfig(config, buildroot_dir) do
    defconfig_content = generate_defconfig(config)
    defconfig_path = Path.join(buildroot_dir, "elixir_minimal_defconfig")
    
    File.write!(defconfig_path, defconfig_content)
    {:ok, defconfig_path}
  end

  defp generate_defconfig(config) do
    """
    # Buildroot configuration for minimal Elixir VM
    # Target: #{config.target_size}MB VM with Elixir #{@elixir_version}
    
    # Architecture
    BR2_x86_64=y
    BR2_x86_core2=y
    
    # Toolchain
    BR2_TOOLCHAIN_BUILDROOT_MUSL=y
    BR2_TOOLCHAIN_BUILDROOT_CXX=y
    BR2_GCC_VERSION_13_X=y
    BR2_BINUTILS_VERSION_2_41_X=y
    BR2_TOOLCHAIN_BUILDROOT_WCHAR=y
    BR2_TOOLCHAIN_BUILDROOT_LOCALE=y
    
    # System configuration
    BR2_TARGET_GENERIC_HOSTNAME="elixir-vm"
    BR2_TARGET_GENERIC_ISSUE="Minimal Elixir VM built with Buildroot"
    BR2_SYSTEM_DHCP="eth0"
    BR2_TARGET_GENERIC_GETTY_PORT="ttyS0"
    BR2_TARGET_GENERIC_GETTY_BAUDRATE_115200=y
    BR2_SYSTEM_DEFAULT_PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin"
    
    # Kernel
    BR2_LINUX_KERNEL=y
    BR2_LINUX_KERNEL_LATEST_VERSION=y
    BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
    BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$(BR2_EXTERNAL_ELIXIR_PATH)/kernel_config"
    BR2_LINUX_KERNEL_COMPRESS_XZ=y
    
    # Root filesystem
    BR2_TARGET_ROOTFS_EXT2=y
    BR2_TARGET_ROOTFS_EXT2_4=y
    BR2_TARGET_ROOTFS_EXT2_SIZE="#{calculate_rootfs_size(config)}"
    BR2_TARGET_ROOTFS_EXT2_COMPRESSION=y
    BR2_TARGET_ROOTFS_EXT2_XZ=y
    
    # Packages - Core system
    BR2_PACKAGE_BUSYBOX=y
    BR2_PACKAGE_DROPBEAR=y
    BR2_PACKAGE_DROPBEAR_CLIENT=y
    
    # Packages - Development
    BR2_PACKAGE_OPENSSL=y
    BR2_PACKAGE_ZLIB=y
    BR2_PACKAGE_NCURSES=y
    BR2_PACKAGE_NCURSES_TARGET_PANEL=y
    BR2_PACKAGE_NCURSES_TARGET_FORM=y
    BR2_PACKAGE_NCURSES_TARGET_MENU=y
    
    # Packages - Erlang/OTP
    BR2_PACKAGE_ERLANG=y
    BR2_PACKAGE_ERLANG_SMP=y
    
    # Package selection for Elixir (custom)
    #{if config.app_path, do: "BR2_PACKAGE_ELIXIR_APP=y", else: ""}
    
    # Bootloader
    BR2_TARGET_GRUB2=y
    BR2_TARGET_GRUB2_X86_64_EFI=y
    
    # Image generation
    BR2_ROOTFS_POST_BUILD_SCRIPT="$(BR2_EXTERNAL_ELIXIR_PATH)/post-build.sh"
    BR2_ROOTFS_POST_IMAGE_SCRIPT="$(BR2_EXTERNAL_ELIXIR_PATH)/post-image.sh"
    """
  end

  defp calculate_rootfs_size(config) do
    base_size = 50  # Base system ~50MB
    erlang_size = 25  # Erlang/OTP ~25MB
    elixir_size = 10  # Elixir ~10MB
    app_size = if config.app_path, do: 10, else: 0  # App overhead ~10MB
    
    total = base_size + erlang_size + elixir_size + app_size
    "#{total}M"
  end

  defp configure_buildroot(buildroot_dir, defconfig_path) do
    # Create external directory for our custom configuration
    external_dir = Path.join(buildroot_dir, "elixir_external")
    File.mkdir_p!(external_dir)
    
    # Create external.mk file
    external_mk = Path.join(external_dir, "external.mk")
    File.write!(external_mk, """
    include $(sort $(wildcard $(BR2_EXTERNAL_ELIXIR_PATH)/package/*/*.mk))
    """)
    
    # Create external.desc
    external_desc = Path.join(external_dir, "external.desc")
    File.write!(external_desc, """
    name: ELIXIR
    desc: Elixir Lean Lab external packages
    """)
    
    # Create Config.in
    config_in = Path.join(external_dir, "Config.in")
    File.write!(config_in, """
    source "$BR2_EXTERNAL_ELIXIR_PATH/package/elixir/Config.in"
    """)
    
    # Create kernel config
    kernel_config_path = Path.join(external_dir, "kernel_config")
    kernel_config = KernelConfig.qemu_minimal()
    kernel_config_content = generate_kernel_config_file(kernel_config)
    File.write!(kernel_config_path, kernel_config_content)
    
    # Create post-build script
    create_post_build_script(external_dir)
    
    # Create post-image script  
    create_post_image_script(external_dir)
    
    # Load the defconfig
    case System.cmd("make", ["BR2_EXTERNAL=#{external_dir}", "elixir_minimal_defconfig"], cd: buildroot_dir) do
      {_, 0} -> {:ok, buildroot_dir}
      {output, _} -> {:error, "Failed to configure Buildroot: #{output}"}
    end
  end

  defp generate_kernel_config_file(kernel_config) do
    header = """
    # Minimal kernel configuration for Elixir VM
    # Generated by ElixirLeanLab
    """
    
    enabled = kernel_config.enable |> Enum.join("\n")
    disabled = kernel_config.disable |> Enum.map(&"# #{&1} is not set") |> Enum.join("\n")
    
    "#{header}\n#{enabled}\n#{disabled}\n"
  end

  defp create_post_build_script(external_dir) do
    script_path = Path.join(external_dir, "post-build.sh")
    
    script_content = """
    #!/bin/bash
    # Post-build script for Elixir VM
    
    TARGET_DIR="$1"
    
    echo "Configuring Elixir VM environment..."
    
    # Set up Elixir paths
    mkdir -p "$TARGET_DIR/usr/local/bin"
    mkdir -p "$TARGET_DIR/usr/local/lib"
    
    # Create elixir wrapper if Erlang is installed
    if [ -x "$TARGET_DIR/usr/bin/erl" ]; then
        cat > "$TARGET_DIR/usr/local/bin/elixir" << 'EOF'
    #!/bin/sh
    export ERL_LIBS="/usr/local/lib/elixir/lib"
    exec erl -pa "/usr/local/lib/elixir/lib/*/ebin" -s elixir start_cli -extra "$@"
    EOF
        chmod +x "$TARGET_DIR/usr/local/bin/elixir"
    fi
    
    # Create iex wrapper
    cat > "$TARGET_DIR/usr/local/bin/iex" << 'EOF'
    #!/bin/sh
    export ERL_LIBS="/usr/local/lib/elixir/lib"
    exec erl -pa "/usr/local/lib/elixir/lib/*/ebin" -s elixir start_cli
    EOF
    chmod +x "$TARGET_DIR/usr/local/bin/iex"
    
    # Optimize for size
    echo "Optimizing system for minimal size..."
    
    # Remove unnecessary files
    find "$TARGET_DIR" -name "*.a" -delete
    find "$TARGET_DIR" -name "*.la" -delete
    find "$TARGET_DIR/usr/share" -name "man" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TARGET_DIR/usr/share" -name "doc" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$TARGET_DIR/usr/share" -name "info" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Strip binaries
    find "$TARGET_DIR" -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true
    
    echo "Post-build optimization complete"
    """
    
    Common.create_script(script_path, script_content)
    :ok
  end

  defp create_post_image_script(external_dir) do
    script_path = Path.join(external_dir, "post-image.sh")
    
    script_content = """
    #!/bin/bash
    # Post-image script for Elixir VM
    
    IMAGES_DIR="$1"
    
    echo "Creating VM image..."
    
    # Create QEMU-compatible disk image
    if command -v qemu-img &> /dev/null; then
        qemu-img create -f qcow2 "$IMAGES_DIR/elixir-vm.qcow2" 100M
        echo "Created qcow2 image: $IMAGES_DIR/elixir-vm.qcow2"
    fi
    
    echo "VM image creation complete"
    """
    
    Common.create_script(script_path, script_content)
    :ok
  end

  defp build_buildroot(buildroot_dir, config) do
    # Start the build process
    case System.cmd("make", ["-j#{System.schedulers()}"], cd: buildroot_dir) do
      {_, 0} ->
        # Collect build artifacts
        images_dir = Path.join(buildroot_dir, "output/images")
        artifacts = %{
          kernel: Path.join(images_dir, "bzImage"),
          rootfs: Path.join(images_dir, "rootfs.ext4.xz"),
          qcow2: Path.join(images_dir, "elixir-vm.qcow2")
        }
        
        {:ok, artifacts}
      
      {output, _} ->
        {:error, "Buildroot build failed: #{output}"}
    end
  end

  defp package_vm_image(artifacts, config) do
    vm_name = "buildroot-vm.tar.xz"
    vm_path = Path.join(config.output_dir, vm_name)
    
    # Create a tarball with all VM components
    files_to_package = [
      artifacts.kernel,
      artifacts.rootfs
    ] ++ (if File.exists?(artifacts.qcow2), do: [artifacts.qcow2], else: [])
    
    # Package with paths relative to images_dir
    images_dir = Path.dirname(artifacts.kernel)
    relative_files = files_to_package |> Enum.map(&Path.basename/1)
    
    with {:ok, _} <- Common.exec_cmd("tar", ["-cJf", vm_path] ++ relative_files, cd: images_dir) do
      {:ok, vm_path}
    end
  end

  @doc """
  Check for required build tools.
  """
  def validate_dependencies do
    Common.check_dependencies(["wget", "tar", "make", "gcc"])
  end

  @doc """
  Estimate the final image size.
  """
  def estimate_size(%Config{} = config) do
    components = [
      kernel: 2,
      rootfs: 50,
      erlang: 25,
      elixir: 10,
      app: if(config.app_path, do: 10, else: 0)
    ]
    Common.estimate_size_string(components)
  end
end