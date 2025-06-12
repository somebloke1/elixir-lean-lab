defmodule ElixirLeanLabTest do
  use ExUnit.Case
  doctest ElixirLeanLab

  alias ElixirLeanLab.Config

  describe "configuration" do
    test "creates config with defaults" do
      config = ElixirLeanLab.configure()
      
      assert config.type == :alpine
      assert config.target_size == 30
      assert config.output_dir == "./build"
      assert config.strip_modules == true
      assert config.compression == :xz
    end

    test "accepts custom options" do
      config = ElixirLeanLab.configure(
        type: :buildroot,
        target_size: 20,
        app: "./test_app",
        packages: ["curl", "git"]
      )
      
      assert config.type == :buildroot
      assert config.target_size == 20
      assert config.app_path == "./test_app"
      assert config.packages == ["curl", "git"]
    end
  end

  describe "config validation" do
    test "validates VM type" do
      config = Config.new(type: :alpine)
      assert {:ok, _} = Config.validate(config)
      
      config = Config.new(type: :invalid)
      assert {:error, _} = Config.validate(config)
    end

    test "validates target size" do
      config = Config.new(target_size: 20)
      assert {:ok, _} = Config.validate(config)
      
      config = Config.new(target_size: -5)
      assert {:error, _} = Config.validate(config)
      
      config = Config.new(target_size: "not a number")
      assert {:error, _} = Config.validate(config)
    end

    test "validates app path when provided" do
      # Create a temp directory for testing
      temp_dir = System.tmp_dir!()
      test_path = Path.join(temp_dir, "test_app_#{:os.system_time()}")
      File.mkdir_p!(test_path)
      
      config = Config.new(app: test_path)
      assert {:ok, _} = Config.validate(config)
      
      # Clean up
      File.rm_rf!(test_path)
      
      # Test non-existent path
      config = Config.new(app: "/non/existent/path")
      assert {:error, _} = Config.validate(config)
    end
  end

  describe "config JSON export" do
    test "exports configuration as JSON" do
      config = Config.new(type: :alpine, target_size: 25)
      json = Config.to_json(config)
      
      parsed = Jason.decode!(json)
      
      assert parsed["architecture"]["name"] == "minimal-vm-alpine"
      assert parsed["architecture"]["target_size"] == "25MB"
      assert parsed["architecture"]["build_method"] == "docker-multi-stage"
      assert parsed["build"]["strip_modules"] == true
    end
  end
end