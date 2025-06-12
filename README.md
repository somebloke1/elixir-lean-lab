# Elixir Lean Lab

Alpine container-based minimal Elixir VM implementation.

## Overview

This project implements the "Balanced VM" architecture from the elixir-lean project, using Alpine Linux containers to achieve a minimal footprint (target: 20-30MB) while maintaining development capabilities.

## Features

- Multi-stage Docker builds for size optimization
- Alpine Linux base with musl libc
- Full IEx shell access
- Production-ready release builds
- Debugging capabilities preserved

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Make (optional, for convenience commands)

### Building

```bash
# Build the Docker image
make build

# Or directly with Docker
docker build -t elixir-lean-lab:latest .
```

### Running

```bash
# Run the container
make run

# Or with docker-compose
make dev

# Access IEx shell
make shell
```

### Check Image Size

```bash
make size
```

## Project Structure

```
.
├── config/          # Runtime configuration
├── lib/             # Application code
├── priv/            # Static assets
├── Dockerfile       # Multi-stage build definition
├── docker-compose.yml
└── Makefile         # Convenience commands
```

## Development

1. Install Elixir locally (optional):
   ```bash
   # Using asdf
   asdf plugin-add elixir
   asdf install elixir 1.15.7-otp-26
   
   # Or using apt
   sudo apt-get install elixir
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Run tests:
   ```bash
   mix test
   ```

## Size Optimization

The Dockerfile uses several techniques to minimize image size:

1. Multi-stage builds to exclude build dependencies
2. Alpine Linux base image
3. Only essential runtime dependencies
4. Stripped binaries
5. No documentation or man pages

## Configuration

The application uses standard Elixir configuration in `config/`.

Environment-specific settings:
- `dev.exs` - Development configuration
- `prod.exs` - Production configuration (used in Docker)
- `test.exs` - Test configuration

## License

MIT