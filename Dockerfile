# =============================================================================
# Build Stage
# =============================================================================
FROM hexpm/elixir:1.15.7-erlang-26.2.1-alpine-3.18.4 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    npm \
    openssl-dev

WORKDIR /app

# Set build environment
ENV MIX_ENV=prod \
    LANG=C.UTF-8

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files first for better caching
COPY mix.exs ./
COPY mix.lock* ./

# Fetch and compile dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy config files
COPY config config

# Copy application source code
COPY lib lib
RUN mkdir -p priv

# Compile the application
RUN mix compile

# Build the release
RUN mix release notification_orchestrator

# =============================================================================
# Runtime Stage
# =============================================================================
FROM alpine:3.18 AS runner

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    libgcc \
    curl \
    ca-certificates \
    && update-ca-certificates

# Create non-root user for security
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

WORKDIR /app

# Copy the release from the builder stage
COPY --from=builder --chown=appuser:appgroup /app/_build/prod/rel/notification_orchestrator ./

# Set environment variables
ENV PHX_SERVER=true \
    MIX_ENV=prod \
    RELEASE_DISTRIBUTION=none \
    LANG=C.UTF-8 \
    TERM=xterm

# Switch to non-root user
USER appuser

# Expose HTTP port and Erlang distribution port
EXPOSE 4004 4369

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4004/health || exit 1

# Start the application
CMD ["bin/notification_orchestrator", "start"]
