# Elixir Lean Lab

Minimal VM builder for Elixir applications. Create optimized Linux-based virtual machines under 30MB for running Elixir/Erlang applications.

## Overview

Elixir Lean Lab provides tools to build minimal virtual machines specifically optimized for Elixir applications. By removing unnecessary components and using efficient build strategies, it creates VMs that are:

- **Small**: 20-30MB total size (compared to 100MB+ for standard distributions)
- **Fast**: Boot in under 2 seconds
- **Secure**: Minimal attack surface with only required components
- **Efficient**: Optimized for BEAM VM performance

## Features

- **Multiple Build Strategies**: Alpine Docker, Buildroot, Nerves, or custom kernel
- **Automatic Size Optimization**: Strips unnecessary OTP applications and files
- **VM Testing Tools**: Launch and analyze VMs with QEMU or Docker
- **Flexible Configuration**: Customize packages, kernel options, and compression
- **Multi-stage Builds**: Separate build and runtime environments
- **Production Ready**: Includes only components needed for production Elixir apps

## Quick Start

### Prerequisites

- Elixir 1.15.7 or higher
- Erlang/OTP 26.2.1 or higher
- Docker (for Alpine builds)
- Git

### Automated Setup

```bash
# Clone the repository
git clone https://github.com/somebloke1/elixir-lean-lab.git
cd elixir-lean-lab

# Run the setup script
./scripts/setup.sh
```

### Building Your First Minimal VM

```bash
# Build a minimal Alpine-based VM
./scripts/build_vm.sh --type alpine --size 25

# Build with a sample application
./scripts/build_vm.sh --type alpine --app ./examples/hello_world --size 20

# Custom output directory
./scripts/build_vm.sh --type alpine --size 30 --output ./my-builds
```

### Using the Elixir API

```elixir
# Configure and build
{:ok, artifacts} = ElixirLeanLab.build(
  type: :alpine,
  target_size: 25,
  app: "./my_app",
  output: "./build"
)

# Analyze the built image
ElixirLeanLab.analyze(artifacts.image)
# => %{
#   total_size: 24_562_432,
#   components: %{
#     erlang: "12.3 MB",
#     elixir: "5.8 MB",
#     system_libs: "3.2 MB",
#     app: "1.5 MB"
#   }
# }

# Launch for testing
{:ok, vm} = ElixirLeanLab.launch(artifacts.image, memory: 256, cpus: 2)
```

## Build Strategies

### Alpine Linux (Implemented)
- Uses Docker multi-stage builds
- Based on Alpine Linux (5MB base)
- musl libc for smaller binaries
- Target size: 20-30MB

### Buildroot (Planned)
- Custom Linux kernel and rootfs
- Ultimate control over components
- Target size: 15-25MB

### Nerves (Planned)
- Elixir-specific embedded Linux
- Pre-optimized for BEAM
- Target size: 18-25MB

### Custom Kernel (Planned)
- Direct kernel compilation
- Minimal initramfs with BEAM
- Target size: 10-20MB

## Project Structure

```
.
├── .github/         # GitHub Actions CI/CD workflows
├── config/          # Runtime configuration
├── docs/            # Architecture and reference documentation
├── examples/        # Example applications
├── lib/             # Core implementation
│   └── elixir_lean_lab/   
│       ├── builder/       # VM builders (Alpine, Buildroot, etc.)
│       ├── config.ex      # Configuration management
│       └── vm.ex          # VM lifecycle management
├── scripts/         # Build and setup scripts
└── test/           # Test suite
```

## Size Optimization Techniques

The Alpine builder implements several optimization strategies:

1. **OTP Application Stripping**: Removes unused OTP apps (wx, debugger, observer, etc.)
2. **Documentation Removal**: Strips all HTML, PDF, and source files
3. **Multi-stage Builds**: Separates build dependencies from runtime
4. **Compression**: XZ compression for maximum size reduction
5. **Static Linking**: Where possible, to avoid shared library overhead

## Development

```bash
# Start interactive shell
iex -S mix

# Run tests
mix test

# Format code
mix format

# Build documentation
mix docs
```

## Performance Characteristics

| Strategy | Image Size | Boot Time | Min RAM | Use Case |
|----------|------------|-----------|---------|-----------|
| Alpine   | 20-30 MB   | < 2s      | 64 MB   | Containers, cloud |
| Buildroot| 15-25 MB   | < 1s      | 32 MB   | Embedded, IoT |
| Nerves   | 18-25 MB   | < 1s      | 64 MB   | Hardware devices |
| Custom   | 10-20 MB   | < 500ms   | 32 MB   | Extreme minimal |

## Contributing

This is an experimental project exploring minimal VM architectures for Elixir. Contributions are welcome, especially for:

- Implementing Buildroot, Nerves, and Custom builders
- Additional size optimization techniques
- Multi-architecture support (ARM64, RISC-V)
- Performance benchmarking tools

## References

The project builds upon research and techniques from:

- [Alpine Linux](https://alpinelinux.org/) - Minimal Linux distribution
- [Buildroot](https://buildroot.org/) - Embedded Linux build system
- [Nerves Project](https://nerves-project.org/) - Elixir embedded platform
- Architecture documents in `docs/` directory

## License

MIT