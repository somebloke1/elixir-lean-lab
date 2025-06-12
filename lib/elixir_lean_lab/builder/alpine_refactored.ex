defmodule ElixirLeanLab.Builder.AlpineRefactored do
  @moduledoc """
  Alpine Linux-based minimal VM builder using Docker multi-stage builds.
  
  This builder creates minimal VMs by:
  1. Using Alpine Linux as the base (smallest mainstream distro)
  2. Multi-stage Docker builds to minimize final image size
  3. Stripping unnecessary Erlang/OTP modules
  4. Using musl libc for smaller binaries
  
  This is the refactored version using the common utilities.
  """

  use ElixirLeanLab.Builder.Behavior
  
  alias ElixirLeanLab.{Builder, Config}
  alias ElixirLeanLab.Builder.{Utils, Common}

  @base_packages ~w(libstdc++ openssl ncurses-libs zlib)
  @build_packages ~w(git build-base nodejs npm python3)

  @impl true
  def validate_dependencies do
    Common.check_dependencies(["docker"])
  end
  
  @impl true
  def estimate_size(%Config{strip_modules: strip} = config) do
    base = 60  # Alpine + Erlang/Elixir
    stripped = if strip, do: -20, else: 0
    app = if config.app_path, do: 10, else: 0
    packages = length(config.packages || []) * 5
    
    total = base + stripped + app + packages
    "#{total}-#{total + 10}MB"
  end
  
  @impl true
  def build(%Config{} = config) do
    with {:ok, build_dir} <- Builder.prepare_build_env(config),
         {:ok, app_dir} <- Builder.prepare_app(config.app_path, build_dir),
         {:ok, dockerfile_path} <- create_dockerfile(config, build_dir),
         {:ok, image_name} <- build_docker_image(dockerfile_path, build_dir),
         {:ok, vm_image} <- export_vm_image(image_name, config) do
      
      Common.report_progress("Alpine VM built successfully")
      Builder.report_size(vm_image)
      
      {:ok, Common.build_result(vm_image, :alpine, %{
        dockerfile: dockerfile_path
      })}
    end
  end

  defp create_dockerfile(config, build_dir) do
    dockerfile_content = generate_dockerfile(config)
    dockerfile_path = Path.join(build_dir, "Dockerfile")
    
    case Utils.write_file(dockerfile_path, dockerfile_content) do
      :ok -> {:ok, dockerfile_path}
      error -> error
    end
  end
  
  defp generate_dockerfile(config) do
    """
    # Multi-stage build for minimal Elixir VM
    # Stage 1: Builder
    FROM elixir:1.15-alpine AS builder

    # Install build dependencies
    RUN apk add --no-cache #{Enum.join(@build_packages, " ")}

    WORKDIR /app

    # Install hex and rebar
    RUN mix local.hex --force && \\
        mix local.rebar --force

    # Copy application source
    #{if config.app_path, do: "COPY #{Path.basename(config.app_path)} .", else: "# No app specified"}

    # Compile application if present
    #{if config.app_path, do: compile_app_commands(), else: "# No app to compile"}

    # Stage 2: Runtime
    FROM alpine:3.19 AS runtime

    # Install runtime dependencies
    RUN apk add --no-cache #{Enum.join(@base_packages ++ (config.packages || []), " ")}

    # Create non-root user
    RUN addgroup -g 1000 elixir && \\
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

    #{Common.otp_strip_dockerfile(config)}

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
    RUN chmod +x /usr/local/bin/* && \\
        chown -R elixir:elixir /usr/local/lib/elixir && \\
        chown -R elixir:elixir /usr/local/lib/erlang
    USER elixir

    #{if config.app_path, do: "CMD [\"/app/bin/start\"]", else: "CMD [\"iex\"]"}

    # Stage 3: VM Export (using scratch for minimal size)
    FROM scratch AS export
    COPY --from=runtime / /
    """
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

  defp build_docker_image(dockerfile_path, build_dir) do
    image_name = "elixir-lean-vm:#{:os.system_time(:second)}"
    
    case Utils.Docker.build(dockerfile_path, build_dir, image_name) do
      {:ok, _} -> {:ok, image_name}
      error -> error
    end
  end

  defp export_vm_image(image_name, config) do
    output_path = Path.join(config.output_dir, "alpine-vm.tar")
    
    with {:ok, _} <- Utils.Docker.save(image_name, output_path) do
      Common.compress_and_cleanup(output_path, config.compression)
    end
  end
end