# syntax=docker/dockerfile:1.4

# Sentinel Auth Agent Container Image
#
# Targets:
#   - auth-agent (default): Distroless production image
#   - auth-agent-prebuilt: For CI with pre-built binaries

ARG RUST_VERSION=1.85
ARG DEBIAN_VARIANT=slim-bookworm

################################################################################
# Build stage - compiles the Rust binary with optimizations
################################################################################
FROM rust:${RUST_VERSION}-${DEBIAN_VARIANT} AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        pkg-config \
        libssl-dev \
        protobuf-compiler \
        cmake \
        build-essential \
        clang \
        libclang-dev \
        libxmlsec1-dev \
        libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy manifest files first for better layer caching
COPY Cargo.toml Cargo.lock ./
COPY src/ src/

# Build release binary with full optimizations
RUN cargo build --release && \
    strip target/release/sentinel-auth-agent

################################################################################
# Production image: Distroless (smallest, most secure)
################################################################################
FROM gcr.io/distroless/cc-debian12:nonroot AS auth-agent

# Copy the binary
COPY --from=builder /app/target/release/sentinel-auth-agent /sentinel-auth-agent

# Labels for container metadata
LABEL org.opencontainers.image.title="Sentinel Auth Agent" \
      org.opencontainers.image.description="Authentication agent for Sentinel reverse proxy" \
      org.opencontainers.image.vendor="Raskell" \
      org.opencontainers.image.source="https://github.com/raskell-io/sentinel-agent-auth"

# Environment variables
ENV RUST_LOG=info,sentinel_auth_agent=debug \
    SOCKET_PATH=/var/run/sentinel/auth.sock

# Run as non-root user
USER nonroot:nonroot

CMD ["/sentinel-auth-agent"]

################################################################################
# Pre-built binary stage (for CI multi-arch builds)
################################################################################
FROM gcr.io/distroless/cc-debian12:nonroot AS auth-agent-prebuilt

COPY sentinel-auth-agent /sentinel-auth-agent

LABEL org.opencontainers.image.title="Sentinel Auth Agent" \
      org.opencontainers.image.description="Authentication agent for Sentinel reverse proxy"

ENV RUST_LOG=info,sentinel_auth_agent=debug \
    SOCKET_PATH=/var/run/sentinel/auth.sock

USER nonroot:nonroot

ENTRYPOINT ["/sentinel-auth-agent"]
