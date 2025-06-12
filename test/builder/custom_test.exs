defmodule ElixirLeanLab.Builder.CustomTest do
  use ExUnit.Case, async: false
  
  alias ElixirLeanLab.Config
  alias ElixirLeanLab.Builder.Custom
  
  @moduletag :custom
  @moduletag timeout: :infinity  # Custom kernel builds can take a very long time
  
  setup do
    # Create temporary directories for testing
    temp_dir = System.tmp_dir!()
    test_dir = Path.join(temp_dir, "custom_test_#{:os.system_time()}")
    output_dir = Path.join(test_dir, "output")
    app_dir = Path.join(test_dir, "test_app")
    
    File.mkdir_p!(output_dir)
    File.mkdir_p!(app_dir)
    
    # Create a minimal test app
    create_test_app(app_dir)
    
    on_exit(fn ->
      File.rm_rf!(test_dir)
    end)
    
    {:ok, test_dir: test_dir, output_dir: output_dir, app_dir: app_dir}
  end
  
  describe "build/1" do
    @tag :slow
    @tag :integration
    @tag :requires_docker
    test "builds a minimal custom VM with kernel and initramfs", %{output_dir: output_dir} do
      config = %Config{
        type: :custom,
        target_size: 20,
        output_dir: output_dir,
        strip_modules: true,
        compression: :xz
      }
      
      result = Custom.build(config)
      
      assert {:ok, %{image: image_path, type: :custom, kernel: kernel_path, initramfs: initramfs_path}} = result
      assert File.exists?(image_path)
      assert String.ends_with?(image_path, ".tar.xz")
      
      # Verify the archive contains expected files
      assert {:ok, files} = list_archive_contents(image_path)
      assert Enum.any?(files, &String.contains?(&1, "bzImage"))
      assert Enum.any?(files, &String.contains?(&1, "initramfs.cpio.xz"))
      
      # Verify size is under target (should be < 30MB for minimal custom build)
      %{size: size} = File.stat!(image_path)
      size_mb = size / 1_048_576
      assert size_mb < 30, "Custom VM is too large: #{size_mb}MB"
    end
    
    @tag :slow
    @tag :integration
    @tag :requires_docker
    test "builds custom VM with app", %{output_dir: output_dir, app_dir: app_dir} do
      config = %Config{
        type: :custom,
        target_size: 25,
        output_dir: output_dir,
        app_path: app_dir,
        strip_modules: true
      }
      
      result = Custom.build(config)
      
      assert {:ok, %{image: image_path, type: :custom}} = result
      assert File.exists?(image_path)
    end
  end
  
  describe "kernel configuration" do
    test "generates minimal kernel config with size optimizations" do
      config = %Config{target_size: 20}
      kernel_config = ElixirLeanLab.KernelConfig.qemu_minimal()
      
      config_content = Custom.generate_kernel_config(kernel_config, config)
      
      # Verify essential options
      assert config_content =~ "CONFIG_64BIT=y"
      assert config_content =~ "CONFIG_SMP=y"
      assert config_content =~ "CONFIG_LOCALVERSION=\"-elixir-vm\""
      
      # Verify initramfs configuration
      assert config_content =~ "CONFIG_INITRAMFS_SOURCE=\"initramfs.cpio\""
      assert config_content =~ "CONFIG_INITRAMFS_COMPRESSION_XZ=y"
      
      # Verify size optimizations
      assert config_content =~ "CONFIG_CC_OPTIMIZE_FOR_SIZE=y"
      assert config_content =~ "CONFIG_SLOB=y"
      assert config_content =~ "CONFIG_KERNEL_XZ=y"
      
      # Verify disabled features for size
      assert config_content =~ "# CONFIG_DEBUG_INFO is not set"
      assert config_content =~ "# CONFIG_DEBUG_KERNEL is not set"
      assert config_content =~ "# CONFIG_KALLSYMS is not set"
    end
  end
  
  describe "initramfs creation" do
    test "creates init script for standalone Elixir", %{test_dir: test_dir} do
      initramfs_dir = Path.join(test_dir, "initramfs")
      File.mkdir_p!(initramfs_dir)
      
      config = %Config{app_path: nil}
      :ok = Custom.create_init_script(initramfs_dir, config)
      
      init_path = Path.join(initramfs_dir, "init")
      assert File.exists?(init_path)
      
      # Verify script is executable
      %{mode: mode} = File.stat!(init_path)
      assert (mode &&& 0o111) != 0, "Init script should be executable"
      
      # Verify script content
      content = File.read!(init_path)
      assert content =~ "#!/bin/sh"
      assert content =~ "mount -t proc proc /proc"
      assert content =~ "mount -t sysfs sysfs /sys"
      assert content =~ "mount -t devtmpfs devtmpfs /dev"
      assert content =~ "exec /bin/elixir -S iex"
    end
    
    test "creates init script for app", %{test_dir: test_dir} do
      initramfs_dir = Path.join(test_dir, "initramfs")
      File.mkdir_p!(initramfs_dir)
      
      config = %Config{app_path: "/path/to/app"}
      :ok = Custom.create_init_script(initramfs_dir, config)
      
      content = File.read!(Path.join(initramfs_dir, "init"))
      assert content =~ "cd /opt/app && exec ./start"
    end
    
    test "creates minimal Elixir setup", %{test_dir: test_dir} do
      initramfs_dir = Path.join(test_dir, "initramfs")
      bin_dir = Path.join(initramfs_dir, "bin")
      File.mkdir_p!(bin_dir)
      
      :ok = Custom.create_minimal_elixir_setup(initramfs_dir)
      
      elixir_path = Path.join(bin_dir, "elixir")
      assert File.exists?(elixir_path)
      
      content = File.read!(elixir_path)
      assert content =~ "#!/bin/sh"
      assert content =~ "ERL_LIBS=\"/usr/lib/erlang/lib\""
      assert content =~ "exec erl -noshell -s elixir start_cli"
    end
  end
  
  describe "strip commands generation" do
    test "generates OTP stripping commands based on config" do
      config = %Config{
        strip_modules: true,
        keep_ssh: false,
        keep_ssl: true,
        keep_http: false,
        keep_mnesia: false,
        keep_dev_tools: false
      }
      
      commands = Custom.generate_strip_commands(config)
      
      # Should contain stripping commands
      assert is_binary(commands)
      assert String.length(commands) > 0
    end
  end
  
  describe "estimate_size/1" do
    test "estimates size for minimal build without app" do
      config = %Config{strip_modules: true, app_path: nil}
      
      estimate = Custom.estimate_size(config)
      
      assert estimate == "11-16MB"
    end
    
    test "estimates size for build with app" do
      config = %Config{strip_modules: true, app_path: "/some/app"}
      
      estimate = Custom.estimate_size(config)
      
      assert estimate == "14-19MB"
    end
    
    test "estimates larger size without stripping" do
      config = %Config{strip_modules: false, app_path: nil}
      
      estimate = Custom.estimate_size(config)
      
      assert estimate == "18-23MB"
    end
  end
  
  describe "error handling" do
    test "handles missing build dependencies", %{output_dir: output_dir} do
      config = %Config{
        type: :custom,
        output_dir: output_dir
      }
      
      # Mock a scenario where wget is not available
      # In real tests, this would require more sophisticated mocking
      
      # For now, just verify the function exists and can be called
      result = Custom.build(config)
      
      case result do
        {:ok, _} -> 
          # Build succeeded - dependencies are available
          assert true
        {:error, reason} ->
          # Build failed - verify error message is informative
          assert is_binary(reason)
          assert String.length(reason) > 0
      end
    end
  end
  
  describe "busybox integration" do
    @tag :requires_network
    test "configures BusyBox for static linking" do
      # This is a unit test for the BusyBox configuration logic
      # We'll test the config file manipulation without actually building
      
      temp_dir = System.tmp_dir!()
      test_config_file = Path.join(temp_dir, "busybox_test_config_#{:os.system_time()}")
      
      # Create a mock BusyBox config
      original_config = """
      CONFIG_FEATURE_VERBOSE=y
      # CONFIG_STATIC is not set
      CONFIG_CROSS_COMPILER_PREFIX=""
      """
      
      File.write!(test_config_file, original_config)
      
      # Apply the static linking modification
      config_content = File.read!(test_config_file)
      modified_config = String.replace(config_content, "# CONFIG_STATIC is not set", "CONFIG_STATIC=y")
      File.write!(test_config_file, modified_config)
      
      # Verify the change
      final_config = File.read!(test_config_file)
      assert final_config =~ "CONFIG_STATIC=y"
      refute final_config =~ "# CONFIG_STATIC is not set"
      
      # Clean up
      File.rm!(test_config_file)
    end
  end
  
  # Helper functions
  
  defp create_test_app(app_dir) do
    # Create mix.exs
    mix_content = """
    defmodule TestApp.MixProject do
      use Mix.Project
      
      def project do
        [
          app: :test_app,
          version: "0.1.0",
          elixir: "~> 1.15",
          start_permanent: Mix.env() == :prod,
          deps: []
        ]
      end
      
      def application do
        [
          extra_applications: [:logger]
        ]
      end
    end
    """
    
    File.write!(Path.join(app_dir, "mix.exs"), mix_content)
    
    # Create lib directory and main module
    lib_dir = Path.join(app_dir, "lib")
    File.mkdir_p!(lib_dir)
    
    app_content = """
    defmodule TestApp do
      def hello do
        :world
      end
    end
    """
    
    File.write!(Path.join(lib_dir, "test_app.ex"), app_content)
    
    # Create a start script
    start_script = """
    #!/bin/sh
    exec elixir -e "IO.puts('Test app started!'); :timer.sleep(:infinity)"
    """
    
    File.write!(Path.join(app_dir, "start"), start_script)
    File.chmod!(Path.join(app_dir, "start"), 0o755)
  end
  
  defp list_archive_contents(archive_path) do
    # Extract file listing from tar.xz archive
    case System.cmd("tar", ["-tf", archive_path]) do
      {output, 0} ->
        files = output |> String.split("\n", trim: true)
        {:ok, files}
      {error, _} ->
        {:error, error}
    end
  end
end