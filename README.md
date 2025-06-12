# Elixir Lean Lab

Experimental Elixir project exploring Lean software development principles through functional programming patterns.

## Overview

This project demonstrates how Lean principles can be applied in Elixir development, leveraging the language's functional paradigm, immutability, and OTP framework to eliminate waste and build quality in.

## Features

- Exploration of Lean principles in functional programming
- Pattern matching for clear, maintainable logic
- OTP patterns for fault-tolerant systems
- Property-based testing with StreamData
- REPL-driven development for rapid experimentation

## Quick Start

### Prerequisites

- Elixir 1.15+ (recommended: use asdf for version management)
- Erlang/OTP 26+

### Setup

```bash
# Install Elixir/Erlang with asdf
asdf plugin-add elixir
asdf plugin-add erlang
asdf install erlang 26.1
asdf install elixir 1.15.7-otp-26

# Or use your system's package manager
# brew install elixir        # macOS
# apt-get install elixir     # Ubuntu/Debian
```

### Development

```bash
# Get dependencies
mix deps.get

# Run tests
mix test

# Start interactive shell
iex -S mix

# Run the application
mix run --no-halt
```

## Project Structure

```
.
├── config/          # Runtime configuration
├── lib/             # Application code
├── test/           # Test files
├── mix.exs         # Project definition and dependencies
└── CLAUDE.md       # Project context and guidelines
```

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