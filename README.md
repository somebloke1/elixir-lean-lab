# Elixir Lean Lab

Experimental Elixir project exploring Lean software development principles through functional programming patterns.

## Overview

This project demonstrates how Lean principles can be applied in Elixir development, leveraging the language's functional paradigm, immutability, and OTP framework to eliminate waste and build quality in.

## Features

- **Lean Pipeline Architecture**: Functional data processing with composable stages
- **Stream Processing**: Lazy evaluation with backpressure support
- **OTP Integration**: Supervised processes for fault-tolerant systems
- **Telemetry Metrics**: Built-in performance monitoring and observability
- **Property-Based Testing**: Comprehensive test coverage with StreamData
- **Zero-Copy Operations**: Efficient data transformation without waste
- **Composable Stages**: 10+ built-in stages for common transformations
- **REPL-Driven Development**: Rapid experimentation and iteration

## Quick Start

### Prerequisites

- Elixir 1.15.7 or higher
- Erlang/OTP 26.2.1 or higher
- Git

### Automated Setup

The easiest way to get started is to use our setup script:

```bash
# Clone the repository
git clone https://github.com/somebloke1/elixir-lean-lab.git
cd elixir-lean-lab

# Run the setup script
./scripts/setup.sh
```

The setup script will:
- ✅ Check for and optionally install asdf version manager
- ✅ Install the correct Erlang/Elixir versions
- ✅ Configure your shell (bash/zsh)
- ✅ Install all dependencies
- ✅ Run tests to verify everything works
- ✅ Provide helpful next steps

### Manual Setup

If you prefer to set up manually:

```bash
# Using asdf (recommended)
asdf plugin-add erlang
asdf plugin-add elixir
asdf install erlang 26.2.1
asdf install elixir 1.15.7-otp-26

# Or use your system's package manager
brew install elixir        # macOS
sudo apt-get install elixir # Ubuntu/Debian
```

### Development

```bash
# Start interactive shell (recommended for development)
iex -S mix

# Run tests
mix test

# Format code
mix format

# Run the demo
./scripts/demo.sh

# Run benchmarks
./scripts/benchmark.sh

# Run full CI suite locally
./scripts/ci.sh
```

## Project Structure

```
.
├── .github/         # GitHub Actions CI/CD workflows
├── config/          # Runtime configuration
├── docs/            # Architecture and usage documentation
├── lib/             # Application code
│   └── lean_pipeline/   # Core pipeline implementation
│       └── stages/      # Pipeline stage implementations
├── scripts/         # Development and operational scripts
├── test/           # Test files
└── mix.exs         # Project definition and dependencies
```

### Key Components

- **LeanPipeline**: Main API for building functional data pipelines
- **LeanPipeline.Flow**: Stream management with backpressure control
- **LeanPipeline.Metrics**: Telemetry-based performance monitoring
- **LeanPipeline.Supervisor**: OTP supervision for fault tolerance
- **Pipeline Stages**: Map, Filter, FlatMap, Window, Take, Drop, Deduplicate, Tap

## Lean Principles Applied

1. **Eliminate Waste**: No unnecessary tooling or dependencies
2. **Build Quality In**: Property-based testing, type specifications
3. **Create Knowledge**: Clear documentation and code patterns
4. **Defer Commitment**: Flexible architecture for experimentation
5. **Deliver Fast**: REPL-driven development, quick feedback loops
6. **Respect People**: Readable code, clear intentions
7. **Optimize the Whole**: System-level thinking with OTP

## Development Workflow

1. Use `iex -S mix` for interactive development
2. Write property-based tests for invariants
3. Document patterns and discoveries
4. Keep modules small and focused
5. Leverage pattern matching for clarity

## Configuration

The application uses standard Elixir configuration in `config/`:
- `config.exs` - Base configuration
- `dev.exs` - Development settings
- `test.exs` - Test configuration
- `prod.exs` - Production settings

## License

MIT