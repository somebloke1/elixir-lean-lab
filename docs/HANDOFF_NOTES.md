# Handoff Notes for Next Developer

**Project**: Elixir Lean Lab - Minimal VM Builder  
**Current State**: Alpine builder complete, other strategies pending  
**Priority**: Verify Alpine works, then implement remaining builders

## Critical Context

This project builds **minimal Linux VMs** (20-30MB) for running Elixir applications. It is NOT about Lean methodology or pipelines - it's about creating the smallest possible VMs.

## Development Strategy: Commit Early, Commit Often ⚡

**IMPORTANT**: Make frequent, small commits as you work. This project has GitHub Actions that will test your changes automatically. Each commit should:

1. **Pass CI tests** - Check `.github/workflows/vm-builder.yml`
2. **Be focused** - One feature or fix per commit
3. **Include tests** - Add tests for new functionality
4. **Update docs** - Keep documentation current

### Suggested Commit Flow
```bash
# After each small change
git add .
git commit -m "feat: implement kernel config validation"
git push origin main

# Watch CI results at:
# https://github.com/somebloke1/elixir-lean-lab/actions
```

### CI Testing Coverage
The GitHub Actions will automatically test:
- ✅ Configuration system
- ✅ OTP stripping logic
- ✅ Kernel configuration generation
- ✅ Benchmark functionality
- ✅ Example app compilation
- ⚠️ Docker builds (limited in CI)

## Task 1: Verify Docker Build Strategy ⚠️

The Alpine builder (`lib/elixir_lean_lab/builder/alpine.ex`) is implemented but **has not been tested with actual Docker builds**. Please verify:

### 1.1 Test Basic Build
```bash
# Ensure Docker is running
docker --version

# Try building without an app
mix run -e 'ElixirLeanLab.build(type: :alpine, target_size: 25)'

# Check output in ./build/
```

**Commit after each working step:**
```bash
git add -A
git commit -m "test: verify Docker availability and basic build"
git push origin main
```

### 1.2 Test with Example App
```bash
# Build with the hello_world example
./scripts/build_vm.sh --type alpine --app ./examples/hello_world --size 20

# Verify the output tar.xz file
```

### 1.3 Known Issues to Check
- Dockerfile syntax in multi-stage build
- Path handling for COPY commands
- XZ compression command availability
- Docker image export format

### 1.4 Expected Output
- File: `./build/alpine-vm.tar.xz`
- Size: 20-30MB compressed
- Should contain minimal Alpine + BEAM + Elixir

**When Docker build works, commit immediately:**
```bash
git add -A
git commit -m "feat: verify Alpine Docker builder produces working VM

- Successfully builds 25MB VM image
- Includes BEAM runtime and Elixir
- XZ compression working
- Output: ./build/alpine-vm.tar.xz"
git push origin main
```

## Task 2: Implement Additional Build Strategies

### 2.1 Buildroot Implementation
**File**: `lib/elixir_lean_lab/builder/buildroot.ex`  
**Target**: 15-25MB images  
**Resources**: 
- Buildroot docs: https://buildroot.org/
- Kernel config: Use `ElixirLeanLab.KernelConfig.qemu_minimal()`
- Reference: `docs/elixir_vm_minimal.ClaudeOpus4.md` (sections on Buildroot)

**Key Steps**:
1. Download Buildroot
2. Configure with minimal kernel + BusyBox + musl
3. Add Erlang/Elixir packages
4. Generate root filesystem
5. Package as bootable image

**Suggested Implementation**:
```elixir
def build(%Config{} = config) do
  # 1. Prepare Buildroot defconfig
  # 2. Run Buildroot make
  # 3. Extract kernel + rootfs
  # 4. Package as qcow2 or raw image
end
```

**Development approach** (commit after each step):
1. `git commit -m "feat: add Buildroot defconfig generation"`
2. `git commit -m "feat: implement Buildroot make process"`
3. `git commit -m "feat: add kernel/rootfs extraction"`
4. `git commit -m "feat: complete Buildroot image packaging"`
5. `git commit -m "test: verify Buildroot builder produces working VM"`

### 2.2 Nerves Implementation  
**File**: `lib/elixir_lean_lab/builder/nerves.ex`  
**Target**: 18-25MB firmware images  
**Resources**:
- Nerves docs: https://hexdocs.pm/nerves/getting-started.html
- Use existing Nerves targets (rpi0, bbb, qemu_arm)

**Key Approach**:
- Leverage Nerves' existing minimal Linux systems
- Focus on qemu_arm target for testing
- Use Nerves.Bootstrap mix tasks

### 2.3 Custom Kernel Implementation
**File**: `lib/elixir_lean_lab/builder/custom.ex`  
**Target**: 10-20MB (most aggressive)  
**Challenge Level**: High

**Approach**:
1. Compile minimal kernel (1-2MB)
2. Create initramfs with:
   - BusyBox statically linked
   - BEAM runtime (stripped)
   - Elixir runtime (stripped)
   - Init script to launch BEAM
3. Use kernel's built-in initramfs support

## Important Architecture Notes

### Size Breakdown (typical)
- Base OS: 5-10MB
- BEAM: 10-15MB
- Elixir: 5-7MB
- App: 1-5MB

### Critical Files to Understand
1. `lib/elixir_lean_lab/otp_stripper.ex` - Removes unnecessary OTP apps
2. `lib/elixir_lean_lab/kernel_config.ex` - Minimal kernel configurations
3. `docs/architecture-balanced-vm-v2.md` - Alpine approach details
4. `docs/elixir_vm_minimal.ClaudeOpus4.md` - Deep technical guide

### Testing Your Implementation
```elixir
# After implementing a builder
{:ok, result} = ElixirLeanLab.build(type: :buildroot)
ElixirLeanLab.analyze(result.image)
ElixirLeanLab.Benchmark.run(result.image)
```

## GitHub Actions & Testing Strategy

### Automatic Testing
Every commit triggers CI that tests:
- Basic functionality without Docker
- Configuration validation
- OTP stripping calculations
- Kernel config generation
- Example app compilation

### Manual Testing (with Docker)
Some tests require Docker and must be run locally:
```bash
# Run full integration test
./scripts/build_vm.sh --type alpine --size 25
./scripts/benchmark_vm.sh ./build/*.tar.xz
```

### Adding New Tests
When implementing new builders, add tests to:
1. `test/elixir_lean_lab_test.exs` - Unit tests
2. `.github/workflows/vm-builder.yml` - CI integration

### Monitoring CI
- Watch: https://github.com/somebloke1/elixir-lean-lab/actions
- Green checkmarks = tests passing
- Red X = something broken, fix before continuing

## Gotchas & Warnings

1. **Don't Remove Core OTP**: kernel, stdlib, crypto, erts are essential
2. **Test BEAM Startup**: Ensure VM can actually run `erl` or `iex`
3. **Memory Constraints**: BEAM needs minimum ~32MB RAM to start
4. **Path Issues**: Be careful with relative vs absolute paths in builders
5. **Compression**: XZ is slow but saves ~50% - make it optional

## Success Criteria

Each builder should produce:
- [ ] Bootable VM image under target size
- [ ] Ability to run `iex` or basic Elixir app
- [ ] Passes benchmark suite
- [ ] Documented configuration options
- [ ] Error handling for common failures

## Success Metrics & Milestones

### Milestone 1: Docker Build Verification
- [ ] Alpine builder produces working 25MB VM
- [ ] VM boots and runs `iex`
- [ ] All CI tests pass
- **Commit**: `feat: verify Alpine Docker builder fully functional`

### Milestone 2: Buildroot Implementation
- [ ] Buildroot builder produces <20MB VM
- [ ] Custom kernel boots in <1 second
- [ ] BEAM starts successfully
- **Commit**: `feat: complete Buildroot minimal VM builder`

### Milestone 3: Additional Builders
- [ ] Nerves builder leverages existing targets
- [ ] Custom kernel builder achieves <15MB
- [ ] All builders pass benchmark tests
- **Commit**: `feat: complete all VM builder strategies`

## Questions You Might Have

**Q: Why not just use Alpine for everything?**  
A: Different use cases - Buildroot for embedded, Nerves for hardware, Custom for absolute minimal.

**Q: Should I implement all builders?**  
A: Focus on one at a time. Buildroot is most valuable after Alpine.

**Q: How small can we really go?**  
A: Theory: 10-15MB. Practice: 20-25MB is more realistic while maintaining functionality.

---

**Remember**: Commit early, commit often, watch CI results!

Good luck! The Alpine builder provides a good template. The key is understanding what can be removed while keeping BEAM functional.