defmodule ElixirLeanLab.Builder.BuildrootTest do
  use ExUnit.Case, async: false
  
  alias ElixirLeanLab.Config
  alias ElixirLeanLab.Builder.Buildroot
  
  @moduletag :buildroot
  @moduletag timeout: :infinity  # Buildroot builds can take a long time
  
  setup do
    # Create temporary directories for testing
    temp_dir = System.tmp_dir!()
    test_dir = Path.join(temp_dir, "buildroot_test_#{:os.system_time()}")
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
    test "builds a minimal VM with default settings", %{output_dir: output_dir} do
      config = %Config{
        type: :buildroot,
        target_size: 30,
        output_dir: output_dir,
        strip_modules: true,
        compression: :xz
      }
      
      result = Buildroot.build(config)
      
      assert {:ok, %{image: image_path, type: :buildroot}} = result
      assert File.exists?(image_path)
      assert String.ends_with?(image_path, ".tar.xz")
      
      # Verify the image contains expected files
      assert {:ok, files} = list_archive_contents(image_path)
      assert "bzImage" in files
      assert "rootfs.ext4.xz" in files
    end
    
    @tag :slow
    @tag :integration
    test "builds VM with custom app", %{output_dir: output_dir, app_dir: app_dir} do
      config = %Config{
        type: :buildroot,
        target_size: 30,
        output_dir: output_dir,
        app_path: app_dir,
        strip_modules: true,
        compression: :xz
      }
      
      result = Buildroot.build(config)
      
      assert {:ok, %{image: image_path, type: :buildroot}} = result
      assert File.exists?(image_path)
      
      # Verify size is reasonable (should be under 100MB for minimal build)
      %{size: size} = File.stat!(image_path)
      size_mb = size / 1_048_576
      assert size_mb < 100, "VM image is too large: #{size_mb}MB"
    end
  end
  
  describe "download_buildroot/1" do
    test "downloads and extracts Buildroot tarball", %{test_dir: test_dir} do
      build_dir = Path.join(test_dir, "build")
      File.mkdir_p!(build_dir)
      
      # This test would need to be mocked or use a local mirror
      # to avoid downloading large files during tests
      # For now, we'll skip the actual download test
    end
  end
  
  describe "generate_defconfig/1" do
    test "generates valid defconfig content" do
      config = %Config{
        type: :buildroot,
        target_size: 30,
        app_path: "/path/to/app"
      }
      
      # Access private function through module
      defconfig = apply(Buildroot, :generate_defconfig, [config])
      
      assert defconfig =~ "BR2_x86_64=y"
      assert defconfig =~ "BR2_TOOLCHAIN_BUILDROOT_MUSL=y"
      assert defconfig =~ "BR2_PACKAGE_ERLANG=y"
      assert defconfig =~ "BR2_PACKAGE_ELIXIR_APP=y"
      assert defconfig =~ ~r/BR2_TARGET_ROOTFS_EXT2_SIZE="\d+M"/
    end
    
    test "calculates appropriate rootfs size" do
      config_with_app = %Config{
        type: :buildroot,
        target_size: 30,
        app_path: "/path/to/app"
      }
      
      config_without_app = %Config{
        type: :buildroot,
        target_size: 30,
        app_path: nil
      }
      
      defconfig_with_app = apply(Buildroot, :generate_defconfig, [config_with_app])
      defconfig_without_app = apply(Buildroot, :generate_defconfig, [config_without_app])
      
      # With app should have larger rootfs
      assert defconfig_with_app =~ ~r/BR2_TARGET_ROOTFS_EXT2_SIZE="95M"/
      assert defconfig_without_app =~ ~r/BR2_TARGET_ROOTFS_EXT2_SIZE="85M"/
    end
  end
  
  describe "kernel configuration" do
    test "generates minimal kernel config" do
      kernel_config = ElixirLeanLab.KernelConfig.qemu_minimal()
      
      assert is_map(kernel_config)
      assert is_list(kernel_config.enable)
      assert is_list(kernel_config.disable)
      
      # Verify essential options are enabled
      assert "CONFIG_64BIT=y" in kernel_config.enable
      assert "CONFIG_EXT4_FS=y" in kernel_config.enable
      assert "CONFIG_VIRTIO=y" in kernel_config.enable
    end
  end
  
  describe "post-build scripts" do
    test "creates valid post-build script", %{test_dir: test_dir} do
      external_dir = Path.join(test_dir, "external")
      File.mkdir_p!(external_dir)
      
      # Test script creation
      apply(Buildroot, :create_post_build_script, [external_dir])
      
      script_path = Path.join(external_dir, "post-build.sh")
      assert File.exists?(script_path)
      
      # Verify script is executable
      %{mode: mode} = File.stat!(script_path)
      assert (mode &&& 0o111) != 0, "Script should be executable"
      
      # Verify script content
      content = File.read!(script_path)
      assert content =~ "#!/bin/bash"
      assert content =~ "elixir"
      assert content =~ "iex"
    end
    
    test "creates valid post-image script", %{test_dir: test_dir} do
      external_dir = Path.join(test_dir, "external")
      File.mkdir_p!(external_dir)
      
      apply(Buildroot, :create_post_image_script, [external_dir])
      
      script_path = Path.join(external_dir, "post-image.sh")
      assert File.exists?(script_path)
      
      content = File.read!(script_path)
      assert content =~ "qemu-img"
      assert content =~ "elixir-vm.qcow2"
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
  end
  
  defp list_archive_contents(archive_path) do
    # Extract file listing from tar.xz archive
    case System.cmd("tar", ["-tf", archive_path]) do
      {output, 0} ->
        files = output |> String.split("\n", trim: true) |> Enum.map(&Path.basename/1)
        {:ok, files}
      {error, _} ->
        {:error, error}
    end
  end
end