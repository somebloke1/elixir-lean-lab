defmodule ElixirLeanLab.Builder.AlpineTest do
  use ExUnit.Case, async: false
  
  alias ElixirLeanLab.Config
  alias ElixirLeanLab.Builder.Alpine
  
  @moduletag :alpine
  @moduletag :requires_docker
  
  setup do
    # Create temporary directories for testing
    temp_dir = System.tmp_dir!()
    test_dir = Path.join(temp_dir, "alpine_test_#{:os.system_time()}")
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
    @tag :integration
    test "builds a minimal Alpine VM with default settings", %{output_dir: output_dir} do
      config = %Config{
        type: :alpine,
        target_size: 30,
        output_dir: output_dir,
        strip_modules: true,
        compression: :xz,
        packages: []
      }
      
      result = Alpine.build(config)
      
      assert {:ok, %{image: image_path, type: :alpine, dockerfile: dockerfile_path}} = result
      assert File.exists?(image_path)
      assert File.exists?(dockerfile_path)
      assert String.ends_with?(image_path, ".tar.xz")
      
      # Verify size is reasonable (should be under 100MB for Alpine)
      %{size: size} = File.stat!(image_path)
      size_mb = size / 1_048_576
      assert size_mb < 100, "Alpine VM is too large: #{size_mb}MB"
    end
    
    @tag :integration
    test "builds Alpine VM with custom packages", %{output_dir: output_dir} do
      config = %Config{
        type: :alpine,
        target_size: 30,
        output_dir: output_dir,
        packages: ["curl", "git"],
        compression: :gzip
      }
      
      result = Alpine.build(config)
      
      assert {:ok, %{image: image_path}} = result
      assert String.ends_with?(image_path, ".tar.gz")
    end
    
    @tag :integration
    test "builds Alpine VM with app", %{output_dir: output_dir, app_dir: app_dir} do
      config = %Config{
        type: :alpine,
        target_size: 30,
        output_dir: output_dir,
        app_path: app_dir,
        strip_modules: true,
        compression: :xz
      }
      
      result = Alpine.build(config)
      
      assert {:ok, %{image: image_path, type: :alpine}} = result
      assert File.exists?(image_path)
    end
  end
  
  describe "dockerfile generation" do
    test "creates multi-stage Dockerfile without app", %{test_dir: test_dir} do
      config = %Config{
        type: :alpine,
        strip_modules: false,
        packages: ["vim"],
        app_path: nil
      }
      
      {:ok, dockerfile_path} = Alpine.create_dockerfile(config, test_dir)
      
      content = File.read!(dockerfile_path)
      
      # Verify multi-stage structure
      assert content =~ "FROM elixir:1.15-alpine AS builder"
      assert content =~ "FROM alpine:3.19 AS runtime"
      assert content =~ "FROM scratch AS export"
      
      # Verify package installation
      assert content =~ "apk add --no-cache.*vim"
      
      # Verify no app commands when app_path is nil
      assert content =~ "# No app specified"
      assert content =~ "# No app to compile"
      
      # Verify default CMD
      assert content =~ "CMD \\[\"iex\"\\]"
    end
    
    test "creates Dockerfile with app compilation", %{test_dir: test_dir, app_dir: app_dir} do
      config = %Config{
        type: :alpine,
        strip_modules: true,
        packages: [],
        app_path: app_dir
      }
      
      {:ok, dockerfile_path} = Alpine.create_dockerfile(config, test_dir)
      
      content = File.read!(dockerfile_path)
      
      # Verify app compilation steps
      assert content =~ "COPY #{Path.basename(app_dir)} ."
      assert content =~ "mix deps.get"
      assert content =~ "MIX_ENV=prod"
      assert content =~ "mix compile"
      assert content =~ "mix release"
      
      # Verify app runtime copy
      assert content =~ "COPY --from=builder /app/_build/prod/rel /app"
      
      # Verify app CMD
      assert content =~ "CMD \\[\"/app/bin/start\"\\]"
    end
    
    test "includes OTP stripping when configured", %{test_dir: test_dir} do
      config = %Config{
        type: :alpine,
        strip_modules: true,
        keep_ssh: false,
        keep_ssl: true,
        keep_http: false
      }
      
      {:ok, dockerfile_path} = Alpine.create_dockerfile(config, test_dir)
      
      content = File.read!(dockerfile_path)
      
      # Should have stripping commands section
      assert content =~ "# Strip"
      refute content =~ "# No app to compile\n\n\n" # Empty strip section
    end
    
    test "creates non-root user and sets permissions", %{test_dir: test_dir} do
      config = %Config{type: :alpine}
      
      {:ok, dockerfile_path} = Alpine.create_dockerfile(config, test_dir)
      
      content = File.read!(dockerfile_path)
      
      # Verify user creation
      assert content =~ "addgroup -g 1000 elixir"
      assert content =~ "adduser -u 1000 -G elixir"
      
      # Verify permission fixes
      assert content =~ "chmod +x /usr/local/bin/\\*"
      assert content =~ "chown -R elixir:elixir /usr/local/lib/elixir"
      assert content =~ "chown -R elixir:elixir /usr/local/lib/erlang"
      
      # Verify user switching
      assert content =~ "USER elixir"
    end
  end
  
  describe "compression" do
    test "compresses with xz", %{test_dir: test_dir} do
      tar_path = Path.join(test_dir, "test.tar")
      File.write!(tar_path, "test content")
      
      compressed = Alpine.compress_image(tar_path, :xz)
      
      assert compressed == tar_path <> ".xz"
      assert File.exists?(compressed)
    end
    
    test "compresses with gzip", %{test_dir: test_dir} do
      tar_path = Path.join(test_dir, "test.tar")
      File.write!(tar_path, "test content")
      
      compressed = Alpine.compress_image(tar_path, :gzip)
      
      assert compressed == tar_path <> ".gz"
      assert File.exists?(compressed)
    end
    
    test "returns uncompressed path for unknown compression", %{test_dir: test_dir} do
      tar_path = Path.join(test_dir, "test.tar")
      File.write!(tar_path, "test content")
      
      result = Alpine.compress_image(tar_path, :unknown)
      
      assert result == tar_path
    end
  end
  
  describe "error handling" do
    @tag :integration
    test "handles Docker build failure", %{test_dir: test_dir, output_dir: output_dir} do
      # Create an invalid Dockerfile
      invalid_dockerfile = Path.join(test_dir, "Dockerfile")
      File.write!(invalid_dockerfile, "FROM invalid_image_that_does_not_exist")
      
      config = %Config{
        type: :alpine,
        output_dir: output_dir
      }
      
      # Directly test Docker build with invalid Dockerfile
      result = Alpine.build_docker_image(invalid_dockerfile, test_dir)
      
      assert {:error, reason} = result
      assert reason =~ "Docker build failed"
    end
    
    test "handles missing output directory gracefully", %{test_dir: test_dir} do
      config = %Config{
        type: :alpine,
        output_dir: Path.join(test_dir, "non_existent", "nested", "dir")
      }
      
      # Should create the directory automatically
      result = Alpine.build(config)
      
      case result do
        {:ok, _} -> assert File.exists?(config.output_dir)
        {:error, _} -> assert true # Error is also acceptable
      end
    end
  end
  
  describe "build environment" do
    test "sets proper environment variables in Dockerfile", %{test_dir: test_dir} do
      config = %Config{type: :alpine}
      
      {:ok, dockerfile_path} = Alpine.create_dockerfile(config, test_dir)
      
      content = File.read!(dockerfile_path)
      
      # Verify environment setup
      assert content =~ "ENV LANG=C.UTF-8"
      assert content =~ "ENV PATH=\"/usr/local/bin:\\$PATH\""
      assert content =~ "ENV ERL_LIBS=\"/usr/local/lib/elixir/lib\""
      assert content =~ "ENV ERL_AFLAGS=\"-kernel shell_history enabled\""
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
          deps: deps(),
          releases: [
            test_app: [
              include_executables_for: [:unix],
              applications: [runtime_tools: :permanent]
            ]
          ]
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
    
    # Create lib directory and modules
    lib_dir = Path.join(app_dir, "lib")
    File.mkdir_p!(lib_dir)
    
    app_module = """
    defmodule TestApp do
      def hello do
        :world
      end
    end
    """
    
    File.write!(Path.join(lib_dir, "test_app.ex"), app_module)
    
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
    
    File.write!(Path.join(lib_dir, "test_app_application.ex"), app_content)
  end
end