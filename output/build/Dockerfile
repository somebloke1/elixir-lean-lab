# Multi-stage build for minimal Elixir VM
# Stage 1: Builder
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git build-base nodejs npm python3

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force &&     mix local.rebar --force

# Copy application source
# No app specified

# Compile application if present
# No app to compile

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

# Remove unnecessary OTP applications
RUN cd /usr/local/lib/erlang/lib && \
    rm -rf diameter-* \
               eldap-* \
               erl_docgen-* \
               et-* \
               ftp-* \
               jinterface-* \
               megaco-* \
               odbc-* \
               snmp-* \
               tftp-* \
               wx-* \
               xmerl-* \
               debugger-* \
               observer-* \
               reltool-* \
               common_test-* \
               eunit-* \
               dialyzer-* \
               edoc-* \
               erl_interface-* \
               parsetools-* \
               tools-* \
               runtime_tools-* \
               sasl-* \
               syntax_tools-* \
               mnesia-* \
               inets-* \
               ssh-*

# Remove documentation and source files
RUN find /usr/local/lib/erlang -name "*.html" -delete && \
    find /usr/local/lib/erlang -name "*.pdf" -delete && \
    find /usr/local/lib/erlang -name "src" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/erlang -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/erlang -name "doc" -type d -exec rm -rf {} + 2>/dev/null || true

# Remove Elixir source files and docs (keep compiled BEAM files)
RUN find /usr/local/lib/elixir -name "*.ex" -delete && \
    find /usr/local/lib/elixir -name "*.html" -delete && \
    find /usr/local/lib/elixir -name "*.md" -delete


# Copy application release if built


USER elixir

# Set up environment
ENV LANG=C.UTF-8
ENV PATH="/usr/local/bin:$PATH"
ENV ERL_LIBS="/usr/local/lib/elixir/lib"
ENV ERL_AFLAGS="-kernel shell_history enabled"

# Fix permissions for Elixir installation
USER root
RUN chmod +x /usr/local/bin/* &&     chown -R elixir:elixir /usr/local/lib/elixir &&     chown -R elixir:elixir /usr/local/lib/erlang
USER elixir

CMD ["iex"]

# Stage 3: VM Export (using scratch for minimal size)
FROM scratch AS export
COPY --from=runtime / /
