defmodule ElixirLeanLab.Builder.Alpine do
  @moduledoc """
  Alpine Linux-based minimal VM builder using Docker multi-stage builds.
  
  This builder creates minimal VMs by:
  1. Using Alpine Linux as the base (smallest mainstream distro)
  2. Multi-stage Docker builds to minimize final image size
  3. Stripping unnecessary Erlang/OTP modules
  4. Using musl libc for smaller binaries
  """

  alias ElixirLeanLab.{Builder, Config, OTPStripper}

  @base_packages ~w(libstdc++ openssl ncurses-libs zlib)
  @build_packages ~w(git build-base nodejs npm python3)

  def build(%Config{} = config) do
    with {:ok, build_dir} <- Builder.prepare_build_env(config),
         {:ok, app_dir} <- Builder.prepare_app(config.app_path, build_dir),
         {:ok, dockerfile_path} <- create_dockerfile(config, build_dir),
         {:ok, image_name} <- build_docker_image(dockerfile_path, build_dir),
         {:ok, vm_image} <- export_vm_image(image_name, config) do
      
      Builder.report_size(vm_image)
      
      {:ok, %{
        image: vm_image,
        type: :alpine,
        size_mb: get_image_size_mb(vm_image),
        dockerfile: dockerfile_path
      }}
    end
  end

  defp create_dockerfile(config, build_dir) do
    dockerfile_content = """
    # Multi-stage build for minimal Elixir VM
    # Stage 1: Builder
    FROM elixir:1.15-alpine AS builder

    # Install build dependencies
    RUN apk add --no-cache #{Enum.join(@build_packages, " ")}

    WORKDIR /app

    # Install hex and rebar
    RUN mix local.hex --force && \
        mix local.rebar --force

    # Copy application source
    #{if config.app_path, do: "COPY #{Path.basename(config.app_path)} .", else: "# No app specified"}

    # Compile application if present
    #{if config.app_path, do: compile_app_commands(), else: "# No app to compile"}

    # Stage 2: Runtime
    FROM alpine:3.19 AS runtime

    # Install runtime dependencies
    RUN apk add --no-cache #{Enum.join(@base_packages ++ config.packages, " ")}

    # Create non-root user
    RUN addgroup -g 1000 elixir && \
        adduser -u 1000 -G elixir -s /bin/sh -D elixir

    WORKDIR /app

    # Copy Erlang/Elixir runtime from builder
    COPY --from=builder /usr/local/lib/erlang /usr/local/lib/erlang
    COPY --from=builder /usr/local/lib/elixir /usr/local/lib/elixir
    COPY --from=builder /usr/local/bin/erl /usr/local/bin/
    COPY --from=builder /usr/local/bin/erlc /usr/local/bin/
    COPY --from=builder /usr/local/bin/elixir /usr/local/bin/
    COPY --from=builder /usr/local/bin/elixirc /usr/local/bin/
    COPY --from=builder /usr/local/bin/iex /usr/local/bin/
    COPY --from=builder /usr/local/bin/mix /usr/local/bin/

    #{if config.strip_modules, do: strip_otp_commands(config), else: ""}

    # Copy application release if built
    #{if config.app_path, do: "COPY --from=builder /app/_build/prod/rel /app", else: ""}

    USER elixir

    # Set up environment
    ENV LANG=C.UTF-8
    ENV PATH="/usr/local/bin:$PATH"
    ENV ERL_LIBS="/usr/local/lib/elixir/lib"
    ENV ERL_AFLAGS="-kernel shell_history enabled"

    # Fix permissions for Elixir installation
    USER root
    RUN chmod +x /usr/local/bin/* && \
        chown -R elixir:elixir /usr/local/lib/elixir && \
        chown -R elixir:elixir /usr/local/lib/erlang
    USER elixir

    #{if config.app_path, do: "CMD [\"/app/bin/start\"]", else: "CMD [\"iex\"]"}

    # Stage 3: VM Export (using scratch for minimal size)
    FROM scratch AS export
    COPY --from=runtime / /
    """

    dockerfile_path = Path.join(build_dir, "Dockerfile")
    File.write!(dockerfile_path, dockerfile_content)
    
    {:ok, dockerfile_path}
  end

  defp compile_app_commands do
    """
    # Get dependencies
    RUN mix deps.get

    # Compile in production mode
    ENV MIX_ENV=prod
    RUN mix compile

    # Create release
    RUN mix release
    """
  end

  defp strip_otp_commands(config \\ %{}) do
    # Get OTP stripping configuration from config
    otp_opts = [
      ssh: Map.get(config, :keep_ssh, false),
      ssl: Map.get(config, :keep_ssl, true),  # Keep SSL by default
      http: Map.get(config, :keep_http, false),
      mnesia: Map.get(config, :keep_mnesia, false),
      dev_tools: Map.get(config, :keep_dev_tools, false)
    ]
    
    OTPStripper.dockerfile_commands(otp_opts)
  end

  defp build_docker_image(dockerfile_path, build_dir) do
    image_name = "elixir-lean-vm:#{:os.system_time(:second)}"
    
    cmd = "docker build -t #{image_name} -f #{dockerfile_path} #{build_dir}"
    
    case System.cmd("docker", ["build", "-t", image_name, "-f", dockerfile_path, build_dir]) do
      {_, 0} -> {:ok, image_name}
      {output, _} -> {:error, "Docker build failed: #{output}"}
    end
  end

  defp export_vm_image(image_name, config) do
    output_path = Path.join(config.output_dir, "alpine-vm.tar")
    
    # Export the Docker image
    case System.cmd("docker", ["save", "-o", output_path, image_name]) do
      {_, 0} ->
        # Optionally compress
        compressed_path = compress_image(output_path, config.compression)
        {:ok, compressed_path}
      
      {output, _} ->
        {:error, "Docker export failed: #{output}"}
    end
  end

  defp compress_image(tar_path, :xz) do
    xz_path = tar_path <> ".xz"
    System.cmd("xz", ["-9", tar_path])
    xz_path
  end
  defp compress_image(tar_path, :gzip) do
    gz_path = tar_path <> ".gz"
    System.cmd("gzip", ["-9", tar_path])
    gz_path
  end
  defp compress_image(tar_path, _), do: tar_path

  defp get_image_size_mb(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> Float.round(size / 1_048_576, 2)
      _ -> 0.0
    end
  end
end