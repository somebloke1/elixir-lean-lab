# VM Builder Validation Guide

## Overview

This guide documents the validation process for Elixir Lean Lab's VM builders. Based on the reflection insights, **validation is critical** - untested code is unreliable code.

## Key Insights from Testing

1. **Alpine Builder**: The only validated builder (77.5MB / 40.3MB compressed)
2. **Other Builders**: Implemented but NOT validated in production
3. **BEAM Reality**: ~58MB irreducible complexity - smaller targets are unrealistic
4. **Testing Requirement**: Every builder needs comprehensive validation

## Running Tests

### Prerequisites

Different builders have different requirements:

- **Alpine**: Docker
- **Buildroot**: wget/curl, tar, make, gcc
- **Nerves**: Mix, Nerves bootstrap
- **Custom**: Docker, wget/curl, tar, make, gcc

### Test Execution

```bash
# Run all tests
mix test

# Run specific builder tests
mix test --only alpine
mix test --only buildroot
mix test --only nerves
mix test --only custom

# Run only fast tests (skip integration)
mix test --exclude slow --exclude integration

# Run with detailed output
mix test --trace
```

### Test Categories

Tests are tagged for selective execution:

- `@tag :integration` - Full build tests (slow, requires dependencies)
- `@tag :slow` - Time-consuming tests
- `@tag :requires_docker` - Tests that need Docker
- `@tag :requires_network` - Tests that download files
- `@tag :unit` - Fast unit tests

## Validation Checklist

For each builder, validate:

### 1. Dependency Checks
```elixir
# Every builder should implement
def validate_dependencies do
  Common.check_dependencies(["required", "commands"])
end
```

### 2. Size Estimation
```elixir
# Provide realistic estimates
def estimate_size(config) do
  # Calculate based on actual component sizes
  # Include overhead for compression
end
```

### 3. Build Process
- [ ] Build completes without errors
- [ ] Output file exists and is valid
- [ ] Size is within expected range
- [ ] Archive contains expected files

### 4. Error Handling
- [ ] Missing dependencies are reported clearly
- [ ] Build failures provide actionable messages
- [ ] Cleanup happens on failure

## Builder-Specific Validation

### Alpine Builder (VALIDATED ✓)
- **Status**: Production ready
- **Actual size**: 77.5MB uncompressed, 40.3MB with xz
- **Key files**: alpine-vm.tar.xz contains Docker image

### Buildroot Builder (NEEDS VALIDATION ⚠️)
- **Expected size**: 85-95MB
- **Key files**: bzImage (kernel), rootfs.ext4.xz
- **Validation**: Requires full Buildroot toolchain

### Nerves Builder (NEEDS VALIDATION ⚠️)
- **Expected size**: 30-50MB firmware
- **Key files**: nerves-vm.fw
- **Validation**: Requires Nerves environment setup

### Custom Builder (NEEDS VALIDATION ⚠️)
- **Expected size**: 15-25MB (most aggressive)
- **Key files**: bzImage, initramfs.cpio.xz
- **Validation**: Requires kernel build environment

## Performance Benchmarks

When validating, record:

1. **Build time**: How long does the build take?
2. **Final size**: Uncompressed and compressed
3. **Memory usage**: Peak memory during build
4. **Dependencies**: What tools are required?

## Common Issues

### 1. Size Larger Than Expected
- BEAM has ~58MB minimum size
- Stripping can save ~20MB max
- Compression typically achieves 50-60% reduction

### 2. Build Failures
- Check all dependencies with `validate_dependencies/0`
- Ensure sufficient disk space (>5GB recommended)
- Run with verbose output for debugging

### 3. Missing Features
- Some builders may not support all config options
- Document limitations in builder module docs

## Validation Results Template

```markdown
## Builder: [Name]
**Date**: [Date tested]
**Status**: ✓ Validated | ⚠️ Partial | ✗ Failed

### Test Results
- Dependency check: [PASS/FAIL]
- Basic build: [PASS/FAIL]
- Build with app: [PASS/FAIL]
- Size validation: [PASS/FAIL]
- Error handling: [PASS/FAIL]

### Measurements
- Build time: [time]
- Output size: [size]MB uncompressed, [size]MB compressed
- Memory peak: [memory]GB

### Notes
[Any issues, limitations, or observations]
```

## Continuous Validation

1. **Before commits**: Run relevant builder tests
2. **In CI**: Run full test suite
3. **After changes**: Re-validate affected builders
4. **Document results**: Update this guide with findings

## Contributing

When adding new builders or features:

1. Write tests FIRST
2. Implement until tests pass
3. Document validation results
4. Update size estimates based on reality

Remember: **No feature is complete without validation!**