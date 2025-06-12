defmodule ElixirLeanLab.KernelConfig do
  @moduledoc """
  Linux kernel configuration for minimal VMs.
  
  Provides kernel configurations optimized for different VM environments
  and use cases, starting from tinyconfig and adding only essential features.
  """

  @doc """
  Generate minimal kernel configuration for QEMU/KVM.
  """
  def qemu_minimal do
    %{
      base: "tinyconfig",
      enable: [
        # Essential for boot
        "CONFIG_64BIT=y",
        "CONFIG_TTY=y",
        "CONFIG_PRINTK=y",
        "CONFIG_BINFMT_ELF=y",
        "CONFIG_BLK_DEV_INITRD=y",
        
        # VirtIO drivers for QEMU
        "CONFIG_VIRTIO=y",
        "CONFIG_VIRTIO_PCI=y",
        "CONFIG_VIRTIO_BLK=y",
        "CONFIG_VIRTIO_NET=y",
        "CONFIG_VIRTIO_CONSOLE=y",
        "CONFIG_HW_RANDOM_VIRTIO=y",
        
        # Basic networking
        "CONFIG_NET=y",
        "CONFIG_INET=y",
        "CONFIG_PACKET=y",
        "CONFIG_UNIX=y",
        
        # Filesystem support
        "CONFIG_EXT4_FS=y",
        "CONFIG_TMPFS=y",
        "CONFIG_PROC_FS=y",
        "CONFIG_SYSFS=y",
        "CONFIG_DEVTMPFS=y",
        "CONFIG_DEVTMPFS_MOUNT=y",
        
        # Memory management
        "CONFIG_SHMEM=y",
        "CONFIG_AIO=y",
        "CONFIG_EVENTFD=y",
        "CONFIG_MEMFD_CREATE=y",
        
        # Security (minimal)
        "CONFIG_MULTIUSER=y",
        "CONFIG_SGETMASK_SYSCALL=y",
        "CONFIG_SYSFS_SYSCALL=y",
        
        # Performance
        "CONFIG_HIGH_RES_TIMERS=y",
        "CONFIG_NO_HZ_IDLE=y",
        "CONFIG_PREEMPT_NONE=y"
      ],
      disable: [
        # Hardware we don't need in VMs
        "CONFIG_SOUND",
        "CONFIG_USB_SUPPORT",
        "CONFIG_I2C",
        "CONFIG_SPI",
        "CONFIG_GPIO_SYSFS",
        "CONFIG_HWMON",
        "CONFIG_THERMAL",
        "CONFIG_WATCHDOG",
        "CONFIG_INPUT_MOUSE",
        "CONFIG_INPUT_KEYBOARD",
        "CONFIG_VGA_CONSOLE",
        
        # Features we don't need
        "CONFIG_SWAP",
        "CONFIG_MODULES",
        "CONFIG_KALLSYMS",
        "CONFIG_DEBUG_KERNEL",
        "CONFIG_FTRACE",
        "CONFIG_KPROBES",
        "CONFIG_PROFILING"
      ]
    }
  end

  @doc """
  Generate kernel config for container environments (Docker/Podman).
  """
  def container_minimal do
    base = qemu_minimal()
    
    %{base | 
      enable: base.enable ++ [
        # Container-specific features
        "CONFIG_NAMESPACES=y",
        "CONFIG_UTS_NS=y",
        "CONFIG_IPC_NS=y",
        "CONFIG_PID_NS=y",
        "CONFIG_NET_NS=y",
        "CONFIG_CGROUPS=y",
        "CONFIG_CGROUP_DEVICE=y",
        "CONFIG_CGROUP_FREEZER=y",
        "CONFIG_CGROUP_PIDS=y",
        "CONFIG_MEMCG=y",
        "CONFIG_VETH=y",
        "CONFIG_BRIDGE=y",
        "CONFIG_NETFILTER=y",
        "CONFIG_NETFILTER_XTABLES=y",
        "CONFIG_NETFILTER_XT_MATCH_CONNTRACK=y",
        "CONFIG_NF_NAT=y",
        "CONFIG_NF_NAT_MASQUERADE=y"
      ]
    }
  end

  @doc """
  Generate kernel config script.
  """
  def generate_config_script(type \\ :qemu_minimal) do
    config = case type do
      :container -> container_minimal()
      _ -> qemu_minimal()
    end
    
    """
    #!/bin/bash
    # Minimal kernel configuration for Elixir VM
    
    # Start with tinyconfig
    make tinyconfig
    
    # Enable essential features
    #{config.enable |> Enum.map(&"echo '#{&1}' >> .config") |> Enum.join("\n")}
    
    # Disable unnecessary features  
    #{config.disable |> Enum.map(&"echo '# #{&1} is not set' >> .config") |> Enum.join("\n")}
    
    # Resolve dependencies
    make olddefconfig
    
    echo "Kernel configuration complete!"
    echo "Estimated kernel size: 1-2MB compressed"
    """
  end

  @doc """
  Get kernel build commands for integration with build systems.
  """
  def build_commands(kernel_version \\ "6.6", arch \\ "x86_64") do
    [
      "wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-#{kernel_version}.tar.xz",
      "tar -xf linux-#{kernel_version}.tar.xz",
      "cd linux-#{kernel_version}",
      "make tinyconfig",
      "# Apply our minimal config",
      "make -j$(nproc)",
      "cp arch/#{arch}/boot/bzImage ../vmlinuz-minimal",
      "echo 'Kernel size:' && ls -lh ../vmlinuz-minimal"
    ]
  end

  @doc """
  Estimate kernel size based on configuration.
  """
  def estimate_size(config_type) do
    case config_type do
      :qemu_minimal -> "1.5-2 MB"
      :container_minimal -> "2-2.5 MB"  
      :full -> "10-15 MB"
      _ -> "Unknown"
    end
  end
end