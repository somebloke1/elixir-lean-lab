
# Multi-stage build for minimal Elixir VM with hello_world app
# Stage 1: Builder
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base nodejs npm python3

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force &&     mix local.rebar --force

# Copy hello_world application
COPY examples/hello_world .

# Get dependencies and compile
ENV MIX_ENV=prod
RUN mix deps.get
RUN mix compile
RUN mix release

# Stage 2: Runtime
FROM alpine:3.19 AS runtime

# Install runtime dependencies
RUN apk add --no-cache libstdc++ openssl ncurses-libs zlib

# Create non-root user
RUN addgroup -g 1000 elixir &&     adduser -u 1000 -G elixir -s /bin/sh -D elixir

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

# Copy application release
COPY --from=builder /app/_build/prod/rel/hello_world ./

# Set up environment
ENV LANG=C.UTF-8
ENV PATH="/usr/local/bin:$PATH"
ENV ERL_LIBS="/usr/local/lib/elixir/lib"
ENV ERL_AFLAGS="-kernel shell_history enabled"

# Fix permissions
USER root
RUN chmod +x /usr/local/bin/* &&     chown -R elixir:elixir /usr/local/lib/elixir &&     chown -R elixir:elixir /usr/local/lib/erlang &&     chown -R elixir:elixir /app
USER elixir

# Start the application
CMD ["./bin/hello_world", "start"]

# Stage 3: VM Export
FROM scratch AS export
COPY --from=runtime / /
