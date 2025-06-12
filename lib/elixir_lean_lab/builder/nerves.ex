defmodule ElixirLeanLab.Builder.Nerves do
  @moduledoc """
  Nerves-based minimal VM builder.
  
  Leverages the Nerves Project for embedded Elixir systems:
  - Pre-built minimal Linux systems
  - Hardware-specific targets
  - Firmware packaging
  - OTA update support
  """

  alias ElixirLeanLab.{Builder, Config}
  alias ElixirLeanLab.Builder.Common

  @nerves_targets %{
    qemu_arm: "nerves_system_qemu_arm",
    rpi0: "nerves_system_rpi0", 
    bbb: "nerves_system_bbb",
    x86_64: "nerves_system_x86_64"
  }

  @default_target :qemu_arm

  def build(%Config{} = config) do
    target = Map.get(config.vm_options || %{}, :nerves_target, @default_target)
    
    with {:ok, build_dir} <- Builder.prepare_build_env(config),
         {:ok, app_dir} <- prepare_nerves_app(config, build_dir),
         {:ok, _} <- setup_nerves_env(build_dir, target),
         {:ok, firmware_path} <- build_nerves_firmware(app_dir, target),
         {:ok, vm_image} <- package_nerves_vm(firmware_path, config) do
      
      Builder.report_size(vm_image)
      
      {:ok, Common.generate_build_report(
        vm_image,
        :nerves,
        %{firmware: firmware_path},
        %{target: target}
      )}
    end
  end

  defp prepare_nerves_app(config, build_dir) do
    app_name = if config.app_path do
      Path.basename(config.app_path)
    else
      "nerves_minimal_vm"
    end
    
    nerves_app_dir = Path.join(build_dir, app_name)
    
    if config.app_path do
      # Copy existing app and add Nerves configuration
      case File.cp_r(config.app_path, nerves_app_dir) do
        {:ok, _} -> 
          add_nerves_config(nerves_app_dir, config)
          {:ok, nerves_app_dir}
        {:error, reason} -> 
          {:error, "Failed to copy app: #{inspect(reason)}"}
      end
    else
      # Create minimal Nerves app
      create_minimal_nerves_app(nerves_app_dir, config)
    end
  end

  defp create_minimal_nerves_app(app_dir, config) do
    File.mkdir_p!(app_dir)
    
    # Create mix.exs
    mix_exs_content = """
    defmodule NervesMinimalVm.MixProject do
      use Mix.Project

      @app :nerves_minimal_vm
      @version "0.1.0"
      @all_targets [:qemu_arm, :rpi0, :bbb, :x86_64]

      def project do
        [
          app: @app,
          version: @version,
          elixir: "~> 1.15",
          archives: [nerves_bootstrap: "~> 1.11"],
          start_permanent: Mix.env() == :prod,
          deps: deps(),
          releases: [{@app, release()}],
          preferred_cli_target: [run: :host, test: :host]
        ]
      end

      def application do
        [
          mod: {NervesMinimalVm.Application, []},
          extra_applications: [:logger, :runtime_tools]
        ]
      end

      defp deps do
        [
          {:nerves, "~> 1.10", runtime: false},
          {:shoehorn, "~> 0.9.1"},
          {:ring_logger, "~> 0.8.5"},
          {:toolshed, "~> 0.3.0"}
        ] ++ deps(@all_targets)
      end

      defp deps(targets) do
        Enum.flat_map(targets, fn target ->
          [{nerves_system_package(target), "~> 1.0", runtime: false, targets: target}]
        end)
      end

      defp nerves_system_package(:qemu_arm), do: :nerves_system_qemu_arm
      defp nerves_system_package(:rpi0), do: :nerves_system_rpi0
      defp nerves_system_package(:bbb), do: :nerves_system_bbb 
      defp nerves_system_package(:x86_64), do: :nerves_system_x86_64

      defp release do
        [
          overwrite: true,
          cookie: "#{@app}_cookie",
          include_erts: &Nerves.Release.erts/0,
          steps: [&Nerves.Release.init/1, :assemble],
          strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
        ]
      end
    end
    """
    
    File.write!(Path.join(app_dir, "mix.exs"), mix_exs_content)
    
    # Create application file
    lib_dir = Path.join(app_dir, "lib")
    File.mkdir_p!(lib_dir)
    
    app_content = """
    defmodule NervesMinimalVm.Application do
      use Application

      def start(_type, _args) do
        children = []
        
        # Print startup message
        IO.puts("🚀 Nerves Minimal VM Started!")
        IO.puts("Target: #{Nerves.Runtime.target()}")
        IO.puts("Memory: #{:erlang.memory(:total) |> format_bytes()}")
        
        opts = [strategy: :one_for_one, name: NervesMinimalVm.Supervisor]
        Supervisor.start_link(children, opts)
      end
      
      defp format_bytes(bytes) do
        mb = bytes / 1_048_576
        "#{Float.round(mb, 2)} MB"
      end
    end
    """
    
    File.write!(Path.join(lib_dir, "nerves_minimal_vm.ex"), app_content)
    
    # Create config files
    config_dir = Path.join(app_dir, "config")
    File.mkdir_p!(config_dir)
    
    config_content = """
    import Config

    config :nerves_minimal_vm, target: Mix.target()

    # Customize non-Elixir parts of the image
    config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

    # Use shoehorn to start the main application
    config :shoehorn,
      init: [:nerves_runtime, :nerves_pack],
      app: Mix.Project.config()[:app]

    # Use Ringlogger as the logger backend and remove :console
    config :logger,
      backends: [RingLogger]

    # Import target specific config
    if Mix.target() != :host do
      import_config "target.exs"
    end
    """
    
    File.write!(Path.join(config_dir, "config.exs"), config_content)
    
    target_config = """
    import Config

    # Configure the network interface
    config :vintage_net,
      regulatory_domain: "US",
      config: [
        {"usb0", %{type: VintageNetDirect}},
        {"eth0",
         %{
           type: VintageNetEthernet,
           ipv4: %{method: :dhcp}
         }}
      ]

    # Configure ssh access
    config :nerves_ssh,
      authorized_keys: [
        File.read!(Path.join(System.user_home!(), ".ssh/id_rsa.pub"))
      ]
    """
    
    File.write!(Path.join(config_dir, "target.exs"), target_config)
    
    {:ok, app_dir}
  end

  defp add_nerves_config(app_dir, _config) do
    # Read existing mix.exs and add Nerves dependencies
    mix_exs_path = Path.join(app_dir, "mix.exs")
    
    if File.exists?(mix_exs_path) do
      content = File.read!(mix_exs_path)
      
      # Add Nerves configuration to existing mix.exs
      # This is a simplified approach - in practice you'd parse and modify the AST
      nerves_deps = """
      
      # Added by ElixirLeanLab for Nerves support
      def nerves_deps do
        [
          {:nerves, "~> 1.10", runtime: false},
          {:shoehorn, "~> 0.9.1"},
          {:ring_logger, "~> 0.8.5"},
          {:nerves_system_qemu_arm, "~> 1.0", runtime: false, targets: :qemu_arm}
        ]
      end
      """
      
      modified_content = content <> nerves_deps
      File.write!(mix_exs_path, modified_content)
    end
  end

  defp setup_nerves_env(build_dir, target) do
    env_vars = [
      {"MIX_ENV", "prod"},
      {"MIX_TARGET", to_string(target)}
    ]
    
    # Install Nerves bootstrap if not present
    case System.cmd("mix", ["archive.install", "hex", "nerves_bootstrap", "--force"], 
                    env: env_vars, cd: build_dir) do
      {_, 0} -> {:ok, target}
      {output, _} -> {:error, "Failed to install Nerves bootstrap: #{output}"}
    end
  end

  defp build_nerves_firmware(app_dir, target) do
    env_vars = [
      {"MIX_ENV", "prod"},
      {"MIX_TARGET", to_string(target)}
    ]
    
    # Get dependencies
    case System.cmd("mix", ["deps.get"], env: env_vars, cd: app_dir) do
      {_, 0} ->
        # Compile
        case System.cmd("mix", ["compile"], env: env_vars, cd: app_dir) do
          {_, 0} ->
            # Build firmware
            case System.cmd("mix", ["firmware"], env: env_vars, cd: app_dir) do
              {_, 0} ->
                firmware_path = Path.join([app_dir, "_build", to_string(target), "prod", "nerves", "images", "nerves_minimal_vm.fw"])
                if File.exists?(firmware_path) do
                  {:ok, firmware_path}
                else
                  {:error, "Firmware file not found at expected location"}
                end
              {output, _} ->
                {:error, "Firmware build failed: #{output}"}
            end
          {output, _} ->
            {:error, "Compilation failed: #{output}"}
        end
      {output, _} ->
        {:error, "Dependency installation failed: #{output}"}
    end
  end

  defp package_nerves_vm(firmware_path, config) do
    vm_name = "nerves-vm.fw"
    vm_path = Path.join(config.output_dir, vm_name)
    
    # Copy firmware to output directory
    case File.cp(firmware_path, vm_path) do
      :ok -> {:ok, vm_path}
      {:error, reason} -> {:error, "Failed to copy firmware: #{inspect(reason)}"}
    end
  end


  @doc """
  Get available Nerves targets.
  """
  def available_targets do
    Map.keys(@nerves_targets)
  end

  @doc """
  Get recommended target for VM development.
  """
  def recommended_target, do: @default_target
end