# FROM rust:1.88-slim AS builder

# # Install build dependencies for both X11 and Wayland
# RUN apt-get update && apt-get install -y \
#     libfreetype6-dev \
#     libexpat1-dev \
#     libpcap-dev \
#     libasound2-dev \
#     libfontconfig1-dev \
#     libgtk-3-dev \
#     pkg-config \
#     && rm -rf /var/lib/apt/lists/*

# WORKDIR /usr/src/sniffnet
# COPY . .

# RUN cargo build --release

# # Runtime stage
# FROM debian:bookworm-slim

# # Install runtime dependencies for both X11 and Wayland
# RUN apt-get update && apt-get install -y \
#     libfreetype6 \
#     libexpat1 \
#     libpcap0.8 \
#     libasound2 \
#     libfontconfig1 \
#     libgtk-3-0 \
#     && rm -rf /var/lib/apt/lists/*

# COPY --from=builder /usr/src/sniffnet/target/release/sniffnet /usr/local/bin/sniffnet

# ENTRYPOINT ["sniffnet"]

# FROM rust:1.88-slim AS builder

# RUN apt-get update && apt-get install -y \
#     libfreetype6-dev \
#     libexpat1-dev \
#     libpcap-dev \
#     libasound2-dev \
#     libfontconfig1-dev \
#     libgtk-3-dev \
#     pkg-config \
#     && rm -rf /var/lib/apt/lists/*

# WORKDIR /usr/src/sniffnet

# COPY Cargo.toml Cargo.lock ./

# RUN mkdir src && echo "fn main() {}" > src/main.rs

# RUN cargo build --release

# COPY src/ src/

# RUN cargo build --release

# FROM debian:bookworm-slim

# RUN apt-get update && apt-get install -y \
#     libfreetype6 \
#     libexpat1 \
#     libpcap0.8 \
#     libasound2 \
#     libfontconfig1 \
#     libgtk-3-0 \
#     && rm -rf /var/lib/apt/lists/*

# COPY --from=builder /usr/src/sniffnet/target/release/sniffnet /usr/local/bin/sniffnet

# ENTRYPOINT ["sniffnet"]

# Stage 0: Install cargo-chef and prepare the dependency recipe
# We use a full Rust image here as chef needs to compile itself.
FROM rust:1.88-slim AS chef

WORKDIR /usr/src/sniffnet

# Install build dependencies required for the project and for cargo-chef to run correctly.
# This layer will be cached as long as these commands don't change.
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libexpat1-dev \
    libpcap-dev \
    libasound2-dev \
    libfontconfig1-dev \
    libgtk-3-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && cargo install cargo-chef --locked # Install cargo-chef

# Copy only Cargo.toml and Cargo.lock to generate the dependency recipe.
# This layer invalidates only when dependencies change.
COPY Cargo.toml Cargo.lock ./

# Generate the dependency recipe. This recipe describes the dependencies.
RUN cargo chef prepare --recipe-path recipe.json

# Stage 1: Build cached dependencies (the "planner" stage)
# This stage compiles all dependencies. It's the longest step, but highly cacheable.
FROM rust:1.88-slim AS planner

WORKDIR /usr/src/sniffnet

# Re-install build dependencies for this stage. This layer will be cached.
# This is necessary because each FROM instruction starts a new build context.
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libexpat1-dev \
    libpcap-dev \
    libasound2-dev \
    libfontconfig1-dev \
    libgtk-3-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy the generated recipe from the 'chef' stage.
COPY --from=chef /usr/src/sniffnet/recipe.json recipe.json

# "Cook" (build) the dependencies based on the recipe.
# This is the most important caching layer. It only rebuilds if recipe.json changes.
RUN cargo chef cook --release --recipe-path recipe.json

# Stage 2: Build the application itself (the "builder" stage)
# This stage copies your actual source code and compiles your application.
FROM rust:1.88-slim AS builder

WORKDIR /usr/src/sniffnet

# Re-install build dependencies for this stage. This layer will be cached.
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libexpat1-dev \
    libpcap-dev \
    libasound2-dev \
    libfontconfig1-dev \
    libgtk-3-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-compiled dependencies from the 'planner' stage.
# This makes the compiled dependencies available for the final build.
COPY --from=planner /usr/src/sniffnet/target target
COPY Cargo.toml Cargo.lock ./

# Copy your actual source code. This layer invalidates frequently.
COPY src/ src/

# Build the application. This step should be fast because dependencies are already built.
RUN cargo build --release

# Stage 3: Final slim runtime image (the "runner" stage)
FROM debian:bookworm-slim

# Install only runtime dependencies needed by the final executable.
RUN apt-get update && apt-get install -y \
    libfreetype6 \
    libexpat1 \
    libpcap0.8 \
    libasound2 \
    libfontconfig1 \
    libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy the final compiled binary from the 'builder' stage.
COPY --from=builder /usr/src/sniffnet/target/release/sniffnet /usr/local/bin/sniffnet

# Set the entrypoint for the application.
ENTRYPOINT ["sniffnet"]



