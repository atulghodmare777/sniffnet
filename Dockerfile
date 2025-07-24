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
# Stage 0: Install cargo-chef and prepare the dependency recipe
# We use a full Rust image here as chef needs to compile itself.
# Stage 0: Install cargo-chef and prepare the dependency recipe
# We use a full Rust image here as chef needs to compile itself.
# Stage 0: Install cargo-chef and prepare the dependency recipe
# We use a full Rust image here as chef needs to compile itself.
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

# Create a dummy src/main.rs to satisfy cargo's requirement for a target.
# This allows `cargo chef prepare` to run successfully.
RUN mkdir src && echo "fn main() {}" > src/main.rs

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

# Copy the cargo-chef binary from the 'chef' stage to make it available in this stage.
COPY --from=chef /usr/local/cargo/bin/cargo-chef /usr/local/bin/cargo-chef

# Copy the generated recipe from the 'chef' stage.
COPY --from=chef /usr/src/sniffnet/recipe.json recipe.json

# Set CARGO_HOME to a custom path for the cache. This is where cargo-chef will put compiled dependencies.
ENV CARGO_HOME=/usr/local/cargo_cache
RUN mkdir -p ${CARGO_HOME}

# "Cook" (build) the dependencies based on the recipe into the custom CARGO_HOME.
# This is the most important caching layer. It only rebuilds if recipe.json changes.
RUN cargo chef cook --release --recipe-path recipe.json --target-dir ${CARGO_HOME}/target

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

# Set CARGO_HOME to the same custom path as planner.
ENV CARGO_HOME=/usr/local/cargo_cache
RUN mkdir -p ${CARGO_HOME}

# Copy the pre-compiled dependencies from the 'planner' stage's custom CARGO_HOME.
# This copies the entire dependency cache, which Cargo will reuse.
COPY --from=planner ${CARGO_HOME} ${CARGO_HOME}

# Copy Cargo.toml, Cargo.lock, src, and resources.
# Ensure the actual src/main.rs and other source files are copied here, overwriting the dummy.
COPY Cargo.toml Cargo.lock ./
COPY src/ src/
COPY resources/ resources/

# Build the application. This step will now find the cached dependencies and
# crucially, will run the project's `build.rs` script to generate necessary files
# like `services.rs` into its own OUT_DIR.
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





