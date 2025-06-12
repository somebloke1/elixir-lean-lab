# Balanced VM Architecture for Elixir Development
## Alpine-Based Docker Container Approach

### Executive Summary

This architecture implements a balanced approach for experimental and educational Elixir development using Alpine Linux containers. Following proven patterns from production deployments, it achieves 20-30MB container sizes while maintaining full debugging capabilities and developer ergonomics.

### Reference Projects and Prior Art

- **[bitwalker/alpine-elixir-phoenix](https://github.com/bitwalker/alpine-elixir-phoenix)** - Production-ready Alpine base images
- **[msaraiva/alpine-erlang](https://github.com/msaraiva/alpine-erlang)** - Minimal Erlang/Elixir images achieving <19MB
- **[heetch/docker-phoenix](https://github.com/heetch/docker-phoenix)** - Phoenix-optimized Alpine containers
- **[AtomVM](https://github.com/atomvm/AtomVM)** - Minimal BEAM implementation for embedded systems
- **[BEAM Docker Release Action](https://github.com/docker-beam/release-action)** - GitHub action for minimal BEAM containers

### Core Architecture Configuration

```json
{
  "architecture": {
    "name": "balanced-vm-alpine",
    "version": "2.0",
    "approach": "container-based",
    "base_os": "alpine-linux",
    "build_method": "docker-multi-stage",
    "target_size": "20-30MB",
    "vm_runtime": "docker/podman/qemu"
  }
}
```

### Build System Configuration

**docker-config.json**:
```json
{
  "build": {
    "base_images": {
      "builder": "elixir:1.15-alpine",
      "runtime": "alpine:3.19"
    },
    "multi_stage": true,
    "optimization": {
      "strip_debug": true,
      "exclude_docs": true,
      "static_assets": "precompiled",
      "mix_env": "prod"
    }
  },
  "runtime": {
    "user": "elixir",
    "workdir": "/app",
    "exposed_ports": [4000, 4369],
    "healthcheck": {
      "test": ["CMD", "wget", "-O", "-", "http://localhost:4000/health"],
      "interval": "30s",
      "timeout": "3s",
      "retries": 3
    }
  }
}
```

### Alpine Package Configuration

**apk-packages.json**:
```json
{
  "runtime_packages": [
    "libstdc++",
    "openssl",
    "ncurses-libs",
    "zlib"
  ],
  "build_packages": [
    "git",
    "build-base",
    "nodejs",
    "npm",
    "python3"
  ],
  "debug_packages": [
    "bash",
    "curl",
    "strace",
    "tcpdump-mini",
    "vim"
  ],
  "package_options": {
    "no_cache": true,
    "virtual_name": ".build-deps",
    "cleanup": true
  }
}
```

### BEAM VM Configuration

**vm-config.json**:
```json
{
  "erlang": {
    "version": "26.2",
    "emu_args": {
      "+sbwt": "none",
      "+sbwtdcpu": "none",
      "+sbwtdio": "none",
      "+swt": "very_low",
      "+sub": true,
      "+K": true,
      "+A": 4,
      "+SDio": 4
    },
    "env_vars": {
      "ERL_CRASH_DUMP_SECONDS": "1",
      "ERL_CRASH_DUMP": "/tmp/erl_crash.dump",
      "ERLANG_COOKIE": "${RELEASE_COOKIE}"
    }
  },
  "elixir": {
    "version": "1.15.7",
    "mix_config": {
      "consolidate_protocols": true,
      "include_erts": false,
      "include_src": false,
      "strip_beams": true
    }
  }
}
```

### Dockerfile Implementation

```dockerfile
# Build stage
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base nodejs npm python3

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy source code
COPY lib lib
COPY priv priv
COPY assets assets

# Build assets
RUN cd assets && npm ci --audit=false && npm run deploy && cd ..

# Create release
ENV MIX_ENV=prod
RUN mix phx.digest && \
    mix release --strip-beams

# Runtime stage
FROM alpine:3.19 AS runtime

# Install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs

# Create app user
RUN addgroup -g 1000 elixir && \
    adduser -u 1000 -G elixir -s /bin/sh -D elixir

# Copy release from builder
WORKDIR /app
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/my_app ./

# Debug-enabled builds include additional tools
ARG ENABLE_DEBUG=false
RUN if [ "$ENABLE_DEBUG" = "true" ]; then \
      apk add --no-cache bash curl strace tcpdump-mini vim; \
    fi

USER elixir

# Health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD /app/bin/my_app eval "MyApp.HealthCheck.check()"

EXPOSE 4000
CMD ["/app/bin/my_app", "start"]
```

### Debugging Configuration

**debug-config.json**:
```json
{
  "development": {
    "tools": ["iex", "observer_cli", "recon", "debugger"],
    "logging": {
      "level": "debug",
      "format": "$time $metadata[$level] $message\n",
      "metadata": ["request_id", "pid", "module"]
    },
    "tracing": {
      "enabled": true,
      "modules": ["MyApp.*"],
      "trace_level": "verbose"
    }
  },
  "remote_debugging": {
    "epmd": {
      "port": 4369,
      "host": "0.0.0.0"
    },
    "distribution": {
      "port_range": [9100, 9105],
      "cookie": "${RELEASE_COOKIE}"
    },
    "observer": {
      "port": 4001,
      "enabled": true
    }
  }
}
```

### Development Environment

**docker-compose.yml**:
```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      args:
        ENABLE_DEBUG: "true"
    ports:
      - "4000:4000"
      - "4369:4369"
      - "9100-9105:9100-9105"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db/my_app_dev
      - SECRET_KEY_BASE=development_secret_key_base
      - PHX_HOST=localhost
      - RELEASE_COOKIE=development_cookie
    volumes:
      - ./:/workspace:cached
      - ~/.ssh:/home/elixir/.ssh:ro
    command: /bin/sh -c "mix deps.get && mix ecto.setup && mix phx.server"

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### QEMU Integration for Local Development

**qemu-config.json**:
```json
{
  "vm_config": {
    "type": "microvm",
    "vcpus": 2,
    "memory": "512M",
    "kernel": "vmlinux",
    "kernel_cmdline": "console=ttyS0 quiet acpi=off",
    "rootfs": {
      "type": "ext4",
      "source": "rootfs.img",
      "readonly": false
    },
    "network": {
      "type": "user",
      "hostfwd": [
        "tcp::4000-:4000",
        "tcp::4369-:4369"
      ]
    }
  },
  "container_runtime": {
    "engine": "podman",
    "rootless": true,
    "mount_workspace": true
  }
}
```

### Size Optimization Strategies

**optimization.json**:
```json
{
  "compile_time": {
    "dead_code_elimination": true,
    "tree_shaking": true,
    "protocol_consolidation": true,
    "strip_beams": true,
    "compress_beams": false
  },
  "runtime": {
    "lazy_loading": true,
    "code_purging": true,
    "minimal_otp_apps": [
      "kernel",
      "stdlib",
      "elixir",
      "logger",
      "runtime_tools",
      "crypto",
      "ssl",
      "public_key"
    ]
  },
  "assets": {
    "minify": true,
    "gzip": true,
    "brotli": false,
    "purgecss": true
  }
}
```

### Monitoring and Observability

**observability.json**:
```json
{
  "metrics": {
    "provider": "telemetry",
    "exporters": ["console", "prometheus"],
    "collection_interval": 60000
  },
  "logging": {
    "backends": ["console", "file"],
    "file_config": {
      "path": "/tmp/app.log",
      "max_size": "10MB",
      "rotation": 5
    }
  },
  "health_checks": {
    "endpoints": [
      {
        "path": "/health",
        "checks": ["database", "cache", "external_apis"]
      },
      {
        "path": "/ready",
        "checks": ["application_started"]
      }
    ]
  }
}
```

### Development Workflow

1. **Local Development**:
   ```bash
   docker-compose up
   docker-compose exec app iex -S mix
   ```

2. **Building Minimal Image**:
   ```bash
   docker build --build-arg ENABLE_DEBUG=false -t my_app:minimal .
   ```

3. **Running in QEMU**:
   ```bash
   # Extract container filesystem
   docker export $(docker create my_app:minimal) | tar -C rootfs -xvf -
   
   # Create disk image
   qemu-img create -f raw rootfs.img 1G
   mkfs.ext4 rootfs.img
   mount -o loop rootfs.img /mnt
   cp -a rootfs/* /mnt/
   umount /mnt
   
   # Run in QEMU
   qemu-system-x86_64 \
     -M microvm,x-option-roms=off,rtc=on \
     -enable-kvm -cpu host -m 512M -smp 2 \
     -kernel vmlinux -append "console=ttyS0 root=/dev/vda" \
     -drive id=root,file=rootfs.img,format=raw,if=none \
     -device virtio-blk-device,drive=root \
     -netdev user,id=net0,hostfwd=tcp::4000-:4000 \
     -device virtio-net-device,netdev=net0 \
     -serial stdio -display none
   ```

### Size Budget Achievement

| Component | Size | Optimization Applied |
|-----------|------|---------------------|
| Alpine base | 5.6MB | Minimal installation |
| Erlang/OTP | 12-15MB | Selected apps only |
| Elixir runtime | 2-3MB | Stripped beams |
| Application | 1-3MB | Consolidated protocols |
| Runtime deps | 1-2MB | Only essentials |
| **Total** | **21-29MB** | Within target |

### Migration Paths

1. **To Production**: Remove debug tools, use distroless base
2. **To Embedded**: Extract release, use Nerves system
3. **To Cloud**: Add orchestration metadata, use registries
4. **To Bare Metal**: Add hardware drivers, init system

### Key Advantages

- **Fast iteration**: Sub-second container rebuilds
- **Full debugging**: Complete tooling available
- **Production-like**: Same Alpine base as production
- **Resource efficient**: 20-30MB images, 50-100MB RAM usage
- **Portable**: Runs on Docker, Podman, or QEMU

This architecture provides a practical, proven approach to minimal Elixir systems while maintaining developer productivity and debugging capabilities.