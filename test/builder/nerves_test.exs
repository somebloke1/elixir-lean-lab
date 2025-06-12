defmodule ElixirLeanLab.Builder.NervesTest do
  use ExUnit.Case, async: false
  
  alias ElixirLeanLab.Config
  alias ElixirLeanLab.Builder.Nerves
  
  @moduletag :nerves
  @moduletag timeout: :infinity  # Nerves builds can take a long time
  
  setup do
    # Create temporary directories for testing
    temp_dir = System.tmp_dir!()
    test_dir = Path.join(temp_dir, "nerves_test_#{:os.system_time()}")
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
    test "builds a minimal Nerves VM with default target", %{output_dir: output_dir} do
      config = %Config{
        type: :nerves,
        target_size: 30,
        output_dir: output_dir
      }
      
      result = Nerves.build(config)
      
      assert {:ok, %{image: image_path, type: :nerves, target: :qemu_arm}} = result
      assert File.exists?(image_path)
      assert String.ends_with?(image_path, ".fw")
      
      # Verify firmware file is valid
      %{size: size} = File.stat!(image_path)
      assert size > 0
    end
    
    @tag :slow
    @tag :integration
    test "builds Nerves VM with custom target", %{output_dir: output_dir} do
      config = %Config{
        type: :nerves,
        target_size: 30,
        output_dir: output_dir,
        vm_options: %{nerves_target: :x86_64}
      }
      
      result = Nerves.build(config)
      
      assert {:ok, %{image: image_path, type: :nerves, target: :x86_64}} = result
      assert File.exists?(image_path)
    end
    
    @tag :slow
    @tag :integration
    test "builds Nerves VM with existing app", %{output_dir: output_dir, app_dir: app_dir} do
      config = %Config{
        type: :nerves,
        target_size: 30,
        output_dir: output_dir,
        app_path: app_dir
      }
      
      result = Nerves.build(config)
      
      assert {:ok, %{image: image_path, type: :nerves}} = result
      assert File.exists?(image_path)
      
      # Verify size is reasonable (Nerves firmware should be under 50MB for minimal build)
      %{size: size} = File.stat!(image_path)
      size_mb = size / 1_048_576
      assert size_mb < 50, "Nerves firmware is too large: #{size_mb}MB"
    end
  end
  
  describe "prepare_nerves_app/2" do
    test "creates minimal Nerves app when no app path provided", %{test_dir: test_dir} do
      config = %Config{type: :nerves}
      
      {:ok, app_dir} = Nerves.prepare_nerves_app(config, test_dir)
      
      assert File.exists?(Path.join(app_dir, "mix.exs"))
      assert File.exists?(Path.join(app_dir, "lib/nerves_minimal_vm.ex"))
      assert File.exists?(Path.join(app_dir, "config/config.exs"))
      assert File.exists?(Path.join(app_dir, "config/target.exs"))
    end
    
    test "adds Nerves configuration to existing app", %{test_dir: test_dir, app_dir: app_dir} do
      config = %Config{type: :nerves, app_path: app_dir}
      
      {:ok, nerves_app_dir} = Nerves.prepare_nerves_app(config, test_dir)
      
      # Should have copied the app and added Nerves config
      assert nerves_app_dir != app_dir
      assert File.exists?(Path.join(nerves_app_dir, "mix.exs"))
      
      # Check that Nerves deps were added
      mix_content = File.read!(Path.join(nerves_app_dir, "mix.exs"))
      assert mix_content =~ "nerves"
      assert mix_content =~ "shoehorn"
    end
  end
  
  describe "minimal Nerves app generation" do
    test "generates valid mix.exs with all targets", %{test_dir: test_dir} do
      app_dir = Path.join(test_dir, "nerves_app")
      {:ok, _} = Nerves.create_minimal_nerves_app(app_dir, %Config{})
      
      mix_content = File.read!(Path.join(app_dir, "mix.exs"))
      
      # Verify mix.exs content
      assert mix_content =~ "use Mix.Project"
      assert mix_content =~ ":nerves_minimal_vm"
      assert mix_content =~ "archives: [nerves_bootstrap:"
      assert mix_content =~ "releases:"
      
      # Verify all targets are included
      assert mix_content =~ ":qemu_arm"
      assert mix_content =~ ":rpi0"
      assert mix_content =~ ":bbb"
      assert mix_content =~ ":x86_64"
      
      # Verify release configuration
      assert mix_content =~ "strip_beams:"
      assert mix_content =~ "&Nerves.Release.erts/0"
    end
    
    test "generates application with startup message", %{test_dir: test_dir} do
      app_dir = Path.join(test_dir, "nerves_app")
      {:ok, _} = Nerves.create_minimal_nerves_app(app_dir, %Config{})
      
      app_content = File.read!(Path.join(app_dir, "lib/nerves_minimal_vm.ex"))
      
      assert app_content =~ "use Application"
      assert app_content =~ "Nerves Minimal VM Started!"
      assert app_content =~ "Nerves.Runtime.target()"
      assert app_content =~ ":erlang.memory(:total)"
    end
    
    test "generates config files with proper settings", %{test_dir: test_dir} do
      app_dir = Path.join(test_dir, "nerves_app")
      {:ok, _} = Nerves.create_minimal_nerves_app(app_dir, %Config{})
      
      # Check main config
      config_content = File.read!(Path.join(app_dir, "config/config.exs"))
      assert config_content =~ "import Config"
      assert config_content =~ ":shoehorn"
      assert config_content =~ "RingLogger"
      assert config_content =~ "import_config \"target.exs\""
      
      # Check target config
      target_content = File.read!(Path.join(app_dir, "config/target.exs"))
      assert target_content =~ ":vintage_net"
      assert target_content =~ "regulatory_domain: \"US\""
      assert target_content =~ ":nerves_ssh"
    end
  end
  
  describe "setup_nerves_env/2" do
    @tag :requires_mix
    test "installs nerves bootstrap archive", %{test_dir: test_dir} do
      # This test requires mix to be available
      # In CI, you might want to skip or mock this
      
      result = Nerves.setup_nerves_env(test_dir, :qemu_arm)
      
      case result do
        {:ok, :qemu_arm} ->
          # Success - archive was installed
          assert true
        {:error, reason} ->
          # Skip if in CI environment without proper setup
          if System.get_env("CI") do
            IO.puts("Skipping Nerves env setup test in CI: #{reason}")
          else
            flunk("Failed to setup Nerves environment: #{reason}")
          end
      end
    end
  end
  
  describe "available_targets/0" do
    test "returns list of supported targets" do
      targets = Nerves.available_targets()
      
      assert :qemu_arm in targets
      assert :rpi0 in targets
      assert :bbb in targets
      assert :x86_64 in targets
    end
  end
  
  describe "recommended_target/0" do
    test "returns default target" do
      assert Nerves.recommended_target() == :qemu_arm
    end
  end
  
  describe "error handling" do
    test "handles missing output directory", %{test_dir: test_dir} do
      config = %Config{
        type: :nerves,
        output_dir: Path.join(test_dir, "non_existent_dir")
      }
      
      result = Nerves.build(config)
      
      assert {:error, _reason} = result
    end
    
    test "handles invalid target", %{output_dir: output_dir} do
      config = %Config{
        type: :nerves,
        output_dir: output_dir,
        vm_options: %{nerves_target: :invalid_target}
      }
      
      # This should fail during the build process
      result = Nerves.build(config)
      
      assert {:error, _reason} = result
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
          extra_applications: [:logger],
          mod: {TestApp.Application, []}
        ]
      end
      
      defp deps, do: []
    end
    """
    
    File.write!(Path.join(app_dir, "mix.exs"), mix_content)
    
    # Create lib directory and main module
    lib_dir = Path.join(app_dir, "lib")
    File.mkdir_p!(lib_dir)
    
    app_content = """
    defmodule TestApp.Application do
      use Application
      
      def start(_type, _args) do
        children = []
        opts = [strategy: :one_for_one, name: TestApp.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    """
    
    File.write!(Path.join(lib_dir, "test_app.ex"), app_content)
  end
end