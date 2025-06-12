# Multi-stage build for minimal Alpine-based Elixir VM
# Target size: 20-30MB

# Stage 1: Build environment
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    npm

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
COPY config ./config

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY lib ./lib
COPY priv ./priv

# Build release
RUN MIX_ENV=prod mix release

# Stage 2: Minimal runtime
FROM alpine:3.18

# Install only runtime dependencies
RUN apk add --no-cache \
    ncurses-libs \
    libstdc++ \
    openssl \
    ca-certificates

# Create non-root user
RUN addgroup -g 1000 elixir && \
    adduser -u 1000 -G elixir -s /bin/sh -D elixir

WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/elixir_lean_lab ./

USER elixir

# Expose default Phoenix port (if needed)
EXPOSE 4000

# Start the release
CMD ["bin/elixir_lean_lab", "start"]