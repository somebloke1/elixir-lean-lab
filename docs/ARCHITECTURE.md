# Elixir Lean Lab Architecture

## Overview

Elixir Lean Lab is a minimal VM builder for Elixir applications. It creates optimized, minimal Linux-based virtual machines specifically tailored for running Elixir/Erlang applications with the smallest possible footprint.

## Goals

1. **Minimal Size**: Achieve VM images under 30MB (target: 20MB)
2. **Fast Boot**: Optimize for quick startup times
3. **Production Ready**: Include only necessary components for production Elixir apps
4. **Multiple Strategies**: Support different build approaches (Alpine, Buildroot, Nerves, Custom)

## Architecture Components

### 1. Configuration System (`ElixirLeanLab.Config`)

Manages build configuration with sensible defaults:
- VM type selection (Alpine, Buildroot, Nerves, Custom)
- Target size constraints
- Package selection
- Kernel configuration options
- VM runtime parameters

### 2. Builder System (`ElixirLeanLab.Builder`)

Modular builder architecture with strategy pattern:

```
ElixirLeanLab.Builder (coordinator)
├── ElixirLeanLab.Builder.Alpine (Docker multi-stage)
├── ElixirLeanLab.Builder.Buildroot (embedded Linux)
├── ElixirLeanLab.Builder.Nerves (Elixir-specific embedded)
└── ElixirLeanLab.Builder.Custom (direct kernel/initramfs)
```

### 3. VM Management (`ElixirLeanLab.VM`)

Handles VM lifecycle:
- Launch VMs using QEMU or Docker
- Analyze image contents and sizes
- Performance benchmarking

## Build Strategies

### Alpine Linux Strategy ✅ (Verified Working)

Uses Docker multi-stage builds to create minimal Alpine-based VMs:

1. **Stage 1 - Builder**:
   - Full Elixir/Erlang development environment
   - Compiles application and dependencies
   - Creates OTP release

2. **Stage 2 - Runtime**:
   - Minimal Alpine base (5MB)
   - Only runtime dependencies
   - Stripped OTP libraries
   - Non-root user

3. **Stage 3 - Export**:
   - Scratch-based final image
   - Minimal attack surface

**Size Optimization Techniques**:
- Remove unnecessary OTP applications (wx, debugger, etc.)
- Strip debug symbols
- Remove documentation and source files
- Use musl libc instead of glibc
- Compress with XZ (highest compression)

### Buildroot Strategy ✅ (Implemented)

For ultimate control over the Linux system:
- Custom kernel configuration (tinyconfig baseline)
- Minimal root filesystem with BusyBox
- Direct hardware support
- Target: 15-25MB images

### Nerves Strategy ✅ (Implemented)

Leverages existing Nerves infrastructure:
- Pre-optimized for embedded Elixir
- Hardware-specific targets (qemu_arm, rpi0, bbb, x86_64)
- Built-in firmware management
- Target: 18-25MB images

### Custom Strategy ✅ (Implemented)

Direct kernel and initramfs manipulation:
- Compile custom Linux kernel (6.6.70)
- Create minimal initramfs with BEAM
- No package manager overhead
- Target: 10-20MB images

## Key Design Decisions

### 1. Modular Builder Pattern

Each build strategy is isolated in its own module, allowing:
- Independent implementation and testing
- Easy addition of new strategies
- Strategy-specific optimizations

### 2. Docker as Primary Build Tool

For Alpine strategy:
- Reproducible builds
- No host system contamination
- Easy CI/CD integration
- Multi-stage optimization

### 3. QEMU for VM Testing

Provides:
- Hardware virtualization
- Network isolation
- Resource constraints
- Cross-platform support

### 4. Incremental Optimization

Start with Alpine (easiest, 20-30MB) and progressively implement more complex strategies for smaller sizes.

## Usage Examples

### Building a Minimal VM

```elixir
# Build Alpine-based VM with default settings
{:ok, artifacts} = ElixirLeanLab.build(
  type: :alpine,
  target_size: 25,
  app: "./my_app"
)

# Analyze the built image
ElixirLeanLab.analyze(artifacts.image)
```

### Custom Configuration

```elixir
config = ElixirLeanLab.configure(
  type: :alpine,
  target_size: 20,
  packages: ["curl"],  # Additional Alpine packages
  strip_modules: true,
  compression: :xz,
  vm_options: %{memory: 128, cpus: 1}
)

{:ok, artifacts} = ElixirLeanLab.Builder.build(config)
```

### Launching for Testing

```elixir
{:ok, vm} = ElixirLeanLab.launch(artifacts.image,
  memory: 256,
  cpus: 2
)
```

## File Structure

```
lib/
├── elixir_lean_lab.ex          # Main API
├── elixir_lean_lab/
│   ├── config.ex               # Configuration management
│   ├── builder.ex              # Builder coordinator
│   ├── builder/
│   │   ├── alpine.ex           # Alpine Linux builder
│   │   ├── buildroot.ex        # Buildroot builder
│   │   ├── nerves.ex           # Nerves builder
│   │   └── custom.ex           # Custom kernel builder
│   └── vm.ex                   # VM management
```

## Performance Targets

| Strategy   | Image Size | Boot Time | RAM Usage | Status |
|------------|------------|-----------|-----------|--------|
| Alpine     | 77.5 MB (40.3 MB compressed) | < 2s | 64-128 MB | ✅ Verified |
| Buildroot  | 15-25 MB   | < 1s      | 32-64 MB  | ✅ Implemented |
| Nerves     | 18-25 MB   | < 1s      | 64-128 MB | ✅ Implemented |
| Custom     | 10-20 MB   | < 500ms   | 32-64 MB  | ✅ Implemented |

## Future Enhancements

1. **Multi-architecture Support**: ARM64, RISC-V
2. **Container Runtime Integration**: Podman, Firecracker
3. **Cloud Provider Images**: AMI, GCE, Azure
4. **Unikernel Exploration**: MirageOS-style approach
5. **Hot Code Loading**: Preserve BEAM's hot upgrade capabilities