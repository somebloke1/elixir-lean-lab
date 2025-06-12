defmodule ElixirLeanLab.Optimizer do
  @moduledoc """
  Advanced optimization strategies for minimal VM builders.
  
  This module provides aggressive optimization techniques learned from
  validation testing to push VM sizes closer to theoretical minimums.
  """
  
  alias ElixirLeanLab.Builder.Common
  require Logger
  
  @doc """
  Performs aggressive OTP application stripping based on actual usage analysis.
  """
  def strip_unused_otp_apps(otp_root, used_apps) do
    all_apps = list_otp_apps(otp_root)
    unused_apps = MapSet.difference(
      MapSet.new(all_apps),
      MapSet.new(used_apps ++ essential_apps())
    )
    
    Logger.info("Found #{Enum.count(unused_apps)} unused OTP applications to remove")
    
    Enum.each(unused_apps, fn app ->
      app_path = Path.join([otp_root, "lib", to_string(app)])
      if File.exists?(app_path) do
        File.rm_rf!(app_path)
        Logger.debug("Removed unused OTP app: #{app}")
      end
    end)
    
    # Also remove the entire documentation directory
    doc_dirs = [
      Path.join(otp_root, "doc"),
      Path.join(otp_root, "man")
    ]
    
    Enum.each(doc_dirs, &File.rm_rf!/1)
    
    {:ok, Enum.count(unused_apps)}
  end
  
  @doc """
  Essential OTP applications that must never be removed.
  """
  def essential_apps do
    [:kernel, :stdlib, :compiler, :elixir, :logger, :crypto, :ssl, :public_key, :asn1]
  end
  
  @doc """
  Performs binary stripping with size tracking.
  """
  def strip_with_metrics(directory) do
    before_size = Common.get_size_mb(directory)
    
    # Strip debug symbols from all binaries
    strip_binaries_aggressive(directory)
    
    after_size = Common.get_size_mb(directory)
    saved = Float.round(before_size - after_size, 2)
    
    Logger.info("Binary stripping saved #{saved}MB")
    {:ok, saved}
  end
  
  @doc """
  Removes all non-essential files with detailed tracking.
  """
  def cleanup_with_metrics(directory) do
    before_size = Common.get_size_mb(directory)
    
    # Remove source files
    remove_source_files(directory)
    
    # Remove build artifacts
    remove_build_artifacts(directory)
    
    # Remove examples and tests
    remove_examples_and_tests(directory)
    
    # Remove unused locales
    remove_unused_locales(directory)
    
    after_size = Common.get_size_mb(directory)
    saved = Float.round(before_size - after_size, 2)
    
    Logger.info("Cleanup saved #{saved}MB")
    {:ok, saved}
  end
  
  @doc """
  Analyzes BEAM file dependencies to identify truly required modules.
  """
  def analyze_beam_dependencies(beam_files) do
    all_modules = MapSet.new()
    
    Enum.each(beam_files, fn beam_file ->
      case :beam_lib.chunks(beam_file, [:imports, :exports, :attributes]) do
        {:ok, {_module, chunks}} ->
          # Extract imported modules
          imports = chunks[:imports] || []
          Enum.each(imports, fn {mod, _} ->
            MapSet.put(all_modules, mod)
          end)
          
        _ ->
          :ok
      end
    end)
    
    all_modules
  end
  
  @doc """
  Optimizes Elixir standard library by removing unused modules.
  """
  def optimize_elixir_stdlib(elixir_lib_path, used_modules) do
    all_beams = Path.wildcard(Path.join([elixir_lib_path, "**", "*.beam"]))
    
    Enum.each(all_beams, fn beam_path ->
      module_name = Path.basename(beam_path, ".beam") |> String.to_atom()
      
      unless module_name in used_modules or essential_elixir_module?(module_name) do
        File.rm!(beam_path)
        Logger.debug("Removed unused Elixir module: #{module_name}")
      end
    end)
  end
  
  defp essential_elixir_module?(module) do
    # Keep core Elixir modules
    prefixes = ["Elixir.Kernel", "Elixir.GenServer", "Elixir.Supervisor", 
                "Elixir.Application", "Elixir.Code", "Elixir.Module"]
    
    module_str = to_string(module)
    Enum.any?(prefixes, &String.starts_with?(module_str, &1))
  end
  
  defp list_otp_apps(otp_root) do
    lib_dir = Path.join(otp_root, "lib")
    
    case File.ls(lib_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&File.dir?(Path.join(lib_dir, &1)))
        |> Enum.map(fn dir ->
          # Extract app name from directory (e.g., "stdlib-5.2" -> :stdlib)
          case String.split(dir, "-") do
            [name | _] -> String.to_atom(name)
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        
      _ ->
        []
    end
  end
  
  defp strip_binaries_aggressive(directory) do
    # Find all ELF binaries
    case System.cmd("find", [
      directory,
      "-type", "f",
      "-exec", "file", "{}", ";"
    ], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "ELF"))
        |> Enum.map(fn line ->
          [path | _] = String.split(line, ":")
          path
        end)
        |> Enum.each(fn binary ->
          # Use aggressive stripping
          System.cmd("strip", [
            "--strip-all",
            "--remove-section=.comment",
            "--remove-section=.note",
            binary
          ], stderr_to_stdout: true)
        end)
        
      _ ->
        :ok
    end
  end
  
  defp remove_source_files(directory) do
    patterns = ["**/*.erl", "**/*.hrl", "**/*.c", "**/*.h", "**/*.cc", "**/*.cpp"]
    
    Enum.each(patterns, fn pattern ->
      files = Path.wildcard(Path.join(directory, pattern))
      Enum.each(files, &File.rm/1)
    end)
  end
  
  defp remove_build_artifacts(directory) do
    patterns = ["**/*.o", "**/*.a", "**/*.la", "**/Makefile", "**/*.mk", 
                "**/.gitignore", "**/*.md", "**/README*", "**/LICENSE*", 
                "**/CHANGELOG*", "**/AUTHORS*", "**/COPYING*"]
    
    Enum.each(patterns, fn pattern ->
      files = Path.wildcard(Path.join(directory, pattern))
      Enum.each(files, &File.rm_rf/1)
    end)
  end
  
  defp remove_examples_and_tests(directory) do
    dirs_to_remove = ["examples", "test", "tests", "spec", "benchmark", "benchmarks"]
    
    Enum.each(dirs_to_remove, fn dir ->
      paths = Path.wildcard(Path.join(directory, "**/#{dir}"))
      Enum.each(paths, &File.rm_rf/1)
    end)
  end
  
  defp remove_unused_locales(directory) do
    locale_dirs = Path.wildcard(Path.join(directory, "**/locale"))
    
    Enum.each(locale_dirs, fn locale_dir ->
      # Keep only English
      File.ls!(locale_dir)
      |> Enum.filter(&(&1 not in ["en", "en_US", "en_US.UTF-8"]))
      |> Enum.each(fn locale ->
        File.rm_rf!(Path.join(locale_dir, locale))
      end)
    end)
  end
  
  @doc """
  Creates a size analysis report for a VM image.
  """
  def analyze_size_breakdown(directory) do
    components = %{
      beam_files: count_and_size(directory, "**/*.beam"),
      so_files: count_and_size(directory, "**/*.so*"),
      binaries: count_and_size_executables(directory),
      otp_apps: analyze_otp_apps(directory),
      elixir: analyze_elixir_size(directory),
      system: analyze_system_files(directory)
    }
    
    total_size = Enum.reduce(components, 0, fn {_, %{size_mb: size}}, acc ->
      acc + size
    end)
    
    %{
      total_size_mb: Float.round(total_size, 2),
      components: components,
      largest: find_largest_files(directory, 20)
    }
  end
  
  defp count_and_size(directory, pattern) do
    files = Path.wildcard(Path.join(directory, pattern))
    
    total_size = Enum.reduce(files, 0, fn file, acc ->
      case File.stat(file) do
        {:ok, %{size: size}} -> acc + size
        _ -> acc
      end
    end)
    
    %{
      count: length(files),
      size_mb: Float.round(total_size / 1_048_576, 2)
    }
  end
  
  defp count_and_size_executables(directory) do
    case System.cmd("find", [directory, "-type", "f", "-executable"], stderr_to_stdout: true) do
      {output, 0} ->
        files = String.split(output, "\n", trim: true)
        
        total_size = Enum.reduce(files, 0, fn file, acc ->
          case File.stat(file) do
            {:ok, %{size: size}} -> acc + size
            _ -> acc
          end
        end)
        
        %{
          count: length(files),
          size_mb: Float.round(total_size / 1_048_576, 2)
        }
        
      _ ->
        %{count: 0, size_mb: 0.0}
    end
  end
  
  defp analyze_otp_apps(directory) do
    otp_lib = Path.join(directory, "usr/local/lib/erlang/lib")
    
    if File.exists?(otp_lib) do
      apps = File.ls!(otp_lib)
      
      app_sizes = Enum.map(apps, fn app ->
        app_path = Path.join(otp_lib, app)
        size = Common.get_size_mb(app_path)
        {app, size}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)
      
      total = Enum.reduce(app_sizes, 0, fn {_, size}, acc -> acc + size end)
      
      %{
        count: length(apps),
        size_mb: Float.round(total, 2),
        top_10: app_sizes
      }
    else
      %{count: 0, size_mb: 0.0, top_10: []}
    end
  end
  
  defp analyze_elixir_size(directory) do
    elixir_paths = [
      Path.join(directory, "usr/local/lib/elixir"),
      Path.join(directory, "usr/local/bin/elixir"),
      Path.join(directory, "usr/local/bin/iex")
    ]
    
    total_size = Enum.reduce(elixir_paths, 0, fn path, acc ->
      if File.exists?(path) do
        acc + get_path_size(path)
      else
        acc
      end
    end)
    
    %{
      size_mb: Float.round(total_size / 1_048_576, 2)
    }
  end
  
  defp analyze_system_files(directory) do
    system_dirs = ["bin", "sbin", "lib", "usr/lib", "usr/bin", "etc", "var"]
    
    total_size = Enum.reduce(system_dirs, 0, fn dir, acc ->
      path = Path.join(directory, dir)
      if File.exists?(path) do
        acc + get_path_size(path)
      else
        acc
      end
    end)
    
    %{
      size_mb: Float.round(total_size / 1_048_576, 2)
    }
  end
  
  defp get_path_size(path) do
    case File.stat(path) do
      {:ok, %{size: size, type: :regular}} -> 
        size
        
      {:ok, %{type: :directory}} ->
        case System.cmd("du", ["-sb", path], stderr_to_stdout: true) do
          {output, 0} ->
            [size_str | _] = String.split(output, "\t")
            String.to_integer(String.trim(size_str))
          _ -> 
            0
        end
        
      _ -> 
        0
    end
  end
  
  defp find_largest_files(directory, count) do
    case System.cmd("find", [directory, "-type", "f", "-exec", "ls", "-la", "{}", ";"], 
                    stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn line ->
          parts = String.split(line, ~r/\s+/)
          if length(parts) >= 9 do
            size = Enum.at(parts, 4) |> String.to_integer() rescue 0
            path = Enum.drop(parts, 8) |> Enum.join(" ")
            {path, size}
          else
            nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(count)
        |> Enum.map(fn {path, size} ->
          %{
            path: String.replace(path, directory <> "/", ""),
            size_mb: Float.round(size / 1_048_576, 2)
          }
        end)
        
      _ ->
        []
    end
  end
end