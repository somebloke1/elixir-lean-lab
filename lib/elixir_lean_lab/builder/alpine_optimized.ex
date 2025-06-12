defmodule ElixirLeanLab.Builder.AlpineOptimized do
  @moduledoc """
  Optimized Alpine Linux builder with aggressive size reduction.
  
  Based on validation results, this builder applies learned optimizations
  to approach the theoretical minimum size while maintaining functionality.
  """
  
  alias ElixirLeanLab.{Builder, Config, OTPStripper, Optimizer}
  alias ElixirLeanLab.Builder.Common
  
  require Logger
  
  # Minimal packages - only what's absolutely required
  @base_packages ~w(libstdc++ openssl ncurses-libs)
  @build_packages ~w(git build-base)
  
  def build(%Config{} = config) do
    with {:ok, build_dir} <- Builder.prepare_build_env(config),
         {:ok, app_dir} <- Builder.prepare_app(config.app_path, build_dir),
         {:ok, dockerfile_path} <- create_optimized_dockerfile(config, build_dir),
         {:ok, image_name} <- build_docker_image(dockerfile_path, build_dir),
         {:ok, temp_container} <- create_temp_container(image_name),
         {:ok, _} <- apply_post_build_optimizations(temp_container),
         {:ok, optimized_image} <- commit_optimized_container(temp_container),
         {:ok, vm_image} <- export_vm_image(optimized_image, config) do
      
      # Clean up temp container
      System.cmd("docker", ["rm", "-f", temp_container])
      
      # Analyze the final size
      analysis = analyze_final_image(optimized_image)
      
      Builder.report_size(vm_image)
      Logger.info("Size breakdown: #{inspect(analysis)}")
      
      {:ok, Common.generate_build_report(
        vm_image,
        :alpine_optimized,
        %{dockerfile: dockerfile_path},
        %{analysis: analysis}
      )}
    end
  end
  
  defp create_optimized_dockerfile(config, build_dir) do
    # Determine which OTP apps are actually needed
    required_apps = if config.app_path do
      analyze_app_dependencies(config.app_path)
    else
      # Minimal set for basic Elixir
      [:kernel, :stdlib, :elixir, :logger, :crypto, :compiler]
    end
    
    dockerfile_content = """
    # Optimized multi-stage build for minimal Elixir VM
    FROM elixir:1.15-alpine AS builder
    
    # Install only essential build dependencies
    RUN apk add --no-cache #{Enum.join(@build_packages, " ")}
    
    WORKDIR /build
    
    # Copy OTP stripper configuration
    RUN echo '#{Jason.encode!(required_apps)}' > /build/required_apps.json
    
    # Prepare stripped OTP installation
    RUN cp -r /usr/local/lib/erlang /build/erlang && \
        cp -r /usr/local/lib/elixir /build/elixir
    
    #{if config.app_path, do: app_build_stage(config), else: ""}
    
    # Stage 2: Optimize
    FROM alpine:3.19 AS optimizer
    
    # Copy build artifacts
    COPY --from=builder /build/erlang /opt/erlang
    COPY --from=builder /build/elixir /opt/elixir
    #{if config.app_path, do: "COPY --from=builder /build/_build/prod /opt/app", else: ""}
    
    # Install optimization tools
    RUN apk add --no-cache binutils file findutils
    
    # Run aggressive optimization
    RUN find /opt -name "*.a" -delete && \
        find /opt -name "*.c" -delete && \
        find /opt -name "*.h" -delete && \
        find /opt -name "*.erl" -delete && \
        find /opt -name "*.hrl" -delete && \
        find /opt -name "*.html" -delete && \
        find /opt -name "*.pdf" -delete && \
        find /opt -name "*.md" -delete && \
        find /opt -name "*.txt" -delete && \
        find /opt -name "*.png" -delete && \
        find /opt -name "*.jpg" -delete && \
        find /opt -name "README*" -delete && \
        find /opt -name "LICENSE*" -delete && \
        find /opt -name "CHANGELOG*" -delete && \
        rm -rf /opt/erlang/lib/*/src && \
        rm -rf /opt/erlang/lib/*/examples && \
        rm -rf /opt/erlang/lib/*/doc && \
        rm -rf /opt/erlang/lib/*/include && \
        rm -rf /opt/elixir/lib/*/test && \
        rm -rf /opt/elixir/lib/*/bench
    
    # Strip all binaries aggressively
    RUN find /opt -type f -executable -exec sh -c 'file "$1" | grep -q ELF && strip --strip-all "$1"' _ {} \\; || true
    
    # Remove unused OTP applications based on analysis
    COPY --from=builder /build/required_apps.json /tmp/
    RUN for app in /opt/erlang/lib/*; do \
          app_name=$(basename "$app" | cut -d- -f1); \
          if ! grep -q "\\"$app_name\\"" /tmp/required_apps.json; then \
            case "$app_name" in \
              kernel|stdlib|crypto|public_key|asn1|ssl|compiler) ;; \
              *) rm -rf "$app" ;; \
            esac; \
          fi; \
        done
    
    # Stage 3: Final minimal image
    FROM alpine:3.19
    
    # Install only runtime dependencies (minimal)
    RUN apk add --no-cache --no-scripts #{Enum.join(@base_packages, " ")} && \
        rm -rf /var/cache/apk/* /tmp/*
    
    # Copy optimized artifacts
    COPY --from=optimizer /opt/erlang /usr/local/lib/erlang
    COPY --from=optimizer /opt/elixir /usr/local/lib/elixir
    #{if config.app_path, do: "COPY --from=optimizer /opt/app /app", else: ""}
    
    # Create minimal symlinks
    RUN ln -s /usr/local/lib/erlang/bin/erl /usr/local/bin/erl && \
        ln -s /usr/local/lib/erlang/bin/epmd /usr/local/bin/epmd && \
        ln -s /usr/local/lib/elixir/bin/elixir /usr/local/bin/elixir && \
        ln -s /usr/local/lib/elixir/bin/iex /usr/local/bin/iex
    
    # Remove package manager and other unnecessary files
    RUN rm -rf /sbin/apk /etc/apk /lib/apk /usr/share/apk && \
        rm -rf /usr/share/man /usr/share/doc /usr/share/info && \
        rm -rf /var/cache/* /var/log/* && \
        find / -name "*.a" -o -name "*.la" | xargs rm -f 2>/dev/null || true
    
    # Set up minimal user
    RUN adduser -D -H -s /sbin/nologin elixir
    
    USER elixir
    WORKDIR #{if config.app_path, do: "/app", else: "/"}
    
    #{if config.app_path, do: "CMD [\\"elixir\\", \\"--no-halt\\", \\"-S\\", \\"mix\\", \\"run\\"]", else: "CMD [\\"iex\\"]"}
    """
    
    dockerfile_path = Path.join(build_dir, "Dockerfile.optimized")
    File.write!(dockerfile_path, dockerfile_content)
    {:ok, dockerfile_path}
  end
  
  defp app_build_stage(config) do
    """
    # Copy and build application
    COPY #{Path.basename(config.app_path)} /build/app
    WORKDIR /build/app
    
    # Get dependencies and compile
    RUN mix local.hex --force && \
        mix local.rebar --force && \
        MIX_ENV=prod mix deps.get && \
        MIX_ENV=prod mix compile
    
    # Create release (more efficient than mix run)
    RUN MIX_ENV=prod mix release --path /build/_build/prod --strip-beams
    """
  end
  
  defp analyze_app_dependencies(app_path) do
    # This is a simplified version - in reality you'd analyze mix.exs and beam files
    base_apps = [:kernel, :stdlib, :elixir, :logger, :crypto, :compiler, :ssl, :public_key, :asn1]
    
    # Check if common dependencies are used
    mix_file = Path.join(app_path, "mix.exs")
    if File.exists?(mix_file) do
      content = File.read!(mix_file)
      
      additional_apps = []
      additional_apps = if content =~ ~r/phoenix/, do: [:phoenix | additional_apps], else: additional_apps
      additional_apps = if content =~ ~r/ecto/, do: [:ecto | additional_apps], else: additional_apps
      additional_apps = if content =~ ~r/poison|jason/, do: [:poison | additional_apps], else: additional_apps
      
      base_apps ++ additional_apps
    else
      base_apps
    end
  end
  
  defp build_docker_image(dockerfile_path, build_dir) do
    image_name = "elixir-minimal-optimized:#{:os.system_time(:second)}"
    
    case System.cmd("docker", ["build", "-f", dockerfile_path, "-t", image_name, build_dir], 
                    stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, image_name}
      {output, _} ->
        {:error, "Docker build failed: #{output}"}
    end
  end
  
  defp create_temp_container(image_name) do
    container_name = "optimize-#{:os.system_time(:second)}"
    
    case System.cmd("docker", ["create", "--name", container_name, image_name]) do
      {container_id, 0} ->
        {:ok, container_name}
      {output, _} ->
        {:error, "Failed to create container: #{output}"}
    end
  end
  
  defp apply_post_build_optimizations(container_name) do
    # Additional optimizations that are easier to do on a created container
    optimization_script = """
    #!/bin/sh
    # Remove any remaining unnecessary files
    find / -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
    find / -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find / -name "test" -type d -path "*/lib/*/test" -exec rm -rf {} + 2>/dev/null || true
    find / -name "*.pyc" -delete 2>/dev/null || true
    find / -name "*.pyo" -delete 2>/dev/null || true
    
    # Clear any caches
    rm -rf /root/.cache /home/*/.cache 2>/dev/null || true
    
    # Remove broken symlinks
    find / -xtype l -delete 2>/dev/null || true
    
    echo "Post-build optimizations complete"
    """
    
    # Copy and execute the script
    script_path = "/tmp/optimize-#{:os.system_time()}.sh"
    File.write!(script_path, optimization_script)
    
    System.cmd("docker", ["cp", script_path, "#{container_name}:/tmp/optimize.sh"])
    System.cmd("docker", ["start", container_name])
    System.cmd("docker", ["exec", container_name, "sh", "/tmp/optimize.sh"])
    System.cmd("docker", ["stop", container_name])
    
    File.rm!(script_path)
    
    {:ok, :optimized}
  end
  
  defp commit_optimized_container(container_name) do
    optimized_image = "elixir-minimal-final:#{:os.system_time(:second)}"
    
    case System.cmd("docker", ["commit", container_name, optimized_image]) do
      {_, 0} -> {:ok, optimized_image}
      {output, _} -> {:error, "Failed to commit container: #{output}"}
    end
  end
  
  defp export_vm_image(image_name, config) do
    tar_name = "alpine-optimized.tar"
    tar_path = Path.join(config.output_dir, tar_name)
    
    with {_, 0} <- System.cmd("docker", ["save", "-o", tar_path, image_name]) do
      compressed_path = compress_image(tar_path, config.compression)
      {:ok, compressed_path}
    else
      {output, _} -> {:error, "Failed to export image: #{output}"}
    end
  end
  
  defp compress_image(tar_path, :xz) do
    xz_path = tar_path <> ".xz"
    
    # Use maximum compression
    case System.cmd("xz", ["-9", "-f", tar_path], env: [{"XZ_OPT", "-9 --threads=0"}]) do
      {_, 0} -> xz_path
      _ -> tar_path
    end
  end
  defp compress_image(tar_path, _), do: tar_path
  
  defp analyze_final_image(image_name) do
    # Get detailed size breakdown
    case System.cmd("docker", ["history", "--no-trunc", image_name]) do
      {output, 0} ->
        lines = String.split(output, "\n", trim: true) |> Enum.drop(1)
        
        total_size = Enum.reduce(lines, 0, fn line, acc ->
          case Regex.run(~r/\s+(\d+(?:\.\d+)?)\s*(MB|KB|GB|B)/, line) do
            [_, size_str, unit] ->
              size = String.to_float(size_str) rescue String.to_integer(size_str)
              
              size_bytes = case unit do
                "B" -> size
                "KB" -> size * 1024
                "MB" -> size * 1_048_576
                "GB" -> size * 1_073_741_824
                _ -> 0
              end
              
              acc + size_bytes
            _ ->
              acc
          end
        end)
        
        %{
          total_mb: Float.round(total_size / 1_048_576, 2),
          layers: length(lines)
        }
        
      _ ->
        %{total_mb: 0.0, layers: 0}
    end
  end
end