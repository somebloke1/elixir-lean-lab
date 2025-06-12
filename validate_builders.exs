#!/usr/bin/env elixir

# Builder Validation Runner
# This script validates all VM builders and reports which ones actually work

defmodule BuilderValidator do
  alias ElixirLeanLab.{Config, Validator}
  alias ElixirLeanLab.Builder.{Alpine, Buildroot, Nerves, Custom}
  
  @builders [
    {:alpine, Alpine, 80, "Docker-based Alpine Linux builder"},
    {:buildroot, Buildroot, 100, "Custom Linux with Buildroot"},
    {:nerves, Nerves, 50, "Nerves embedded systems"},
    {:custom, Custom, 90, "Direct kernel + initramfs"}
  ]
  
  def run do
    IO.puts """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║           Elixir Lean Lab - Builder Validation Suite              ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║ Testing all VM builders to verify which ones actually work        ║
    ║ This will attempt to build and validate minimal VMs               ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """
    
    results = Enum.map(@builders, &validate_builder/1)
    
    report_results(results)
    save_validation_report(results)
  end
  
  defp validate_builder({type, module, target_size, description}) do
    IO.puts "\n#{IO.ANSI.cyan()}▶ Testing #{String.upcase(to_string(type))} builder#{IO.ANSI.reset()}"
    IO.puts "  #{description}"
    IO.puts "  Target size: #{target_size}MB"
    
    # Check dependencies first
    IO.write "  Checking dependencies... "
    
    case Validator.validate_dependencies(type) do
      :ok ->
        IO.puts "#{IO.ANSI.green()}✓#{IO.ANSI.reset()}"
        
        # Try to build
        config = %Config{
          type: type,
          target_size: target_size,
          output_dir: Path.join(System.tmp_dir!(), "validate-#{type}-#{:os.system_time()}"),
          optimization_level: :standard
        }
        
        File.mkdir_p!(config.output_dir)
        
        IO.write "  Building VM... "
        build_start = System.monotonic_time(:millisecond)
        
        build_result = case module.build(config) do
          {:ok, result} ->
            build_time = System.monotonic_time(:millisecond) - build_start
            IO.puts "#{IO.ANSI.green()}✓#{IO.ANSI.reset()} (#{format_duration(build_time)})"
            
            # Validate the image
            IO.write "  Validating image... "
            validation_result = Validator.validate_image(result.image, config)
            
            case validation_result do
              {:ok, report} ->
                IO.puts "#{IO.ANSI.green()}✓#{IO.ANSI.reset()}"
                print_validation_details(report)
                {:success, result, report, build_time}
                
              {:error, reason} ->
                IO.puts "#{IO.ANSI.red()}✗#{IO.ANSI.reset()}"
                IO.puts "    Error: #{reason}"
                {:build_ok_validation_failed, result, reason, build_time}
            end
            
          {:error, reason} ->
            build_time = System.monotonic_time(:millisecond) - build_start
            IO.puts "#{IO.ANSI.red()}✗#{IO.ANSI.reset()}"
            IO.puts "    Error: #{inspect(reason)}"
            {:build_failed, reason, build_time}
        end
        
        # Cleanup
        File.rm_rf!(config.output_dir)
        
        {type, build_result}
        
      {:error, missing_deps} ->
        IO.puts "#{IO.ANSI.yellow()}⚠#{IO.ANSI.reset()}"
        IO.puts "    Missing: #{missing_deps}"
        {type, {:missing_dependencies, missing_deps}}
    end
  end
  
  defp print_validation_details(report) do
    validations = report.validations
    
    IO.puts "    #{check_mark(validations.exists)} File exists"
    IO.puts "    #{check_mark(validations.size_acceptable)} Size acceptable"
    IO.puts "    #{check_mark(validations.bootable)} Bootable"
    IO.puts "    #{check_mark(validations.functional)} Functional"
  end
  
  defp check_mark(true), do: "#{IO.ANSI.green()}✓#{IO.ANSI.reset()}"
  defp check_mark(false), do: "#{IO.ANSI.red()}✗#{IO.ANSI.reset()}"
  
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{div(ms, 60000)}m #{rem(div(ms, 1000), 60)}s"
  
  defp report_results(results) do
    IO.puts "\n#{IO.ANSI.bright()}╔═══════════════════════════════════════════════════════════════════╗#{IO.ANSI.reset()}"
    IO.puts "#{IO.ANSI.bright()}║                      VALIDATION SUMMARY                           ║#{IO.ANSI.reset()}"
    IO.puts "#{IO.ANSI.bright()}╚═══════════════════════════════════════════════════════════════════╝#{IO.ANSI.reset()}"
    
    success_count = Enum.count(results, fn {_, result} ->
      match?({:success, _, _, _}, result)
    end)
    
    IO.puts "\nTotal builders tested: #{length(results)}"
    IO.puts "Successful builds: #{IO.ANSI.green()}#{success_count}#{IO.ANSI.reset()}"
    IO.puts "Failed builds: #{IO.ANSI.red()}#{length(results) - success_count}#{IO.ANSI.reset()}"
    
    IO.puts "\n#{IO.ANSI.bright()}Detailed Results:#{IO.ANSI.reset()}"
    IO.puts String.duplicate("─", 70)
    
    Enum.each(results, fn {type, result} ->
      type_str = String.pad_trailing(String.upcase(to_string(type)), 12)
      
      status_str = case result do
        {:success, build_result, _, build_time} ->
          "#{IO.ANSI.green()}✓ SUCCESS#{IO.ANSI.reset()} - #{build_result.size_mb}MB in #{format_duration(build_time)}"
          
        {:build_ok_validation_failed, build_result, reason, _} ->
          "#{IO.ANSI.yellow()}⚠ BUILT#{IO.ANSI.reset()} - Validation failed: #{reason}"
          
        {:build_failed, reason, _} ->
          "#{IO.ANSI.red()}✗ FAILED#{IO.ANSI.reset()} - #{shorten_error(reason)}"
          
        {:missing_dependencies, deps} ->
          "#{IO.ANSI.yellow()}⚠ SKIPPED#{IO.ANSI.reset()} - Missing: #{deps}"
      end
      
      IO.puts "#{type_str} #{status_str}"
    end)
    
    # Find the winner
    successful = Enum.filter(results, fn {_, result} ->
      match?({:success, _, _, _}, result)
    end)
    
    if length(successful) > 0 do
      {winner_type, {:success, build_result, _, _}} = 
        Enum.min_by(successful, fn {_, {:success, build_result, _, _}} ->
          build_result.size_mb
        end)
      
      IO.puts "\n#{IO.ANSI.bright()}🏆 Smallest working VM: #{String.upcase(to_string(winner_type))} at #{build_result.size_mb}MB#{IO.ANSI.reset()}"
    else
      IO.puts "\n#{IO.ANSI.yellow()}⚠ No builders produced validated VMs#{IO.ANSI.reset()}"
    end
  end
  
  defp shorten_error(reason) when is_binary(reason) do
    if String.length(reason) > 50 do
      String.slice(reason, 0, 47) <> "..."
    else
      reason
    end
  end
  defp shorten_error(reason), do: inspect(reason) |> shorten_error()
  
  defp save_validation_report(results) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    report = %{
      timestamp: timestamp,
      host: :inet.gethostname() |> elem(1) |> to_string(),
      results: Enum.map(results, fn {type, result} ->
        %{
          builder: type,
          status: status_from_result(result),
          details: details_from_result(result)
        }
      end)
    }
    
    filename = "validation_report_#{Date.utc_today()}.json"
    File.write!(filename, Jason.encode!(report, pretty: true))
    
    IO.puts "\n#{IO.ANSI.cyan()}📄 Validation report saved to: #{filename}#{IO.ANSI.reset()}"
  end
  
  defp status_from_result({:success, _, _, _}), do: "success"
  defp status_from_result({:build_ok_validation_failed, _, _, _}), do: "validation_failed"
  defp status_from_result({:build_failed, _, _}), do: "build_failed"
  defp status_from_result({:missing_dependencies, _}), do: "missing_dependencies"
  
  defp details_from_result({:success, build_result, validation, build_time}) do
    %{
      size_mb: build_result.size_mb,
      build_time_ms: build_time,
      validations: validation.validations
    }
  end
  defp details_from_result({:build_ok_validation_failed, build_result, reason, build_time}) do
    %{
      size_mb: build_result.size_mb,
      build_time_ms: build_time,
      validation_error: to_string(reason)
    }
  end
  defp details_from_result({:build_failed, reason, build_time}) do
    %{
      build_time_ms: build_time,
      error: to_string(reason)
    }
  end
  defp details_from_result({:missing_dependencies, deps}) do
    %{missing_dependencies: deps}
  end
end

# Ensure we can load the project modules
Code.require_file("lib/elixir_lean_lab.ex")
Code.require_file("lib/elixir_lean_lab/config.ex")
Code.require_file("lib/elixir_lean_lab/validator.ex")
Code.require_file("lib/elixir_lean_lab/builder.ex")
Code.require_file("lib/elixir_lean_lab/builder/common.ex")
Code.require_file("lib/elixir_lean_lab/builder/alpine.ex")
Code.require_file("lib/elixir_lean_lab/builder/buildroot.ex")
Code.require_file("lib/elixir_lean_lab/builder/nerves.ex")
Code.require_file("lib/elixir_lean_lab/builder/custom.ex")

# Add Jason for JSON encoding
Mix.install([{:jason, "~> 1.4"}])

# Run the validator
BuilderValidator.run()