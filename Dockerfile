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
RUN mkdir -p src && echo "fn main() {}" > src/main.rs

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

# "Cook" (build) the dependencies based on the recipe.
# This will populate the planner's target directory with compiled dependencies.
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

# Copy the entire `target` directory from the 'planner' stage.
# This includes all compiled dependencies and their metadata, allowing Cargo
# to correctly reuse them and run `build.rs` for the main crate.
COPY --from=planner /usr/src/sniffnet/target ./target

# Copy Cargo.toml and Cargo.lock
COPY Cargo.toml Cargo.lock ./

# Copy your actual source code and resources.
# This is where the real `src/main.rs` and `resources/` are brought in.
COPY src/ src/
COPY resources/ resources/

# Build the application. This step will now:
# 1. Find the cached dependencies from the previous copy.
# 2. Crucially, run the project's `build.rs` script (if it exists in your `src/` directory).
#    The `build.rs` output (like `services.rs`) will be generated into this stage's `target` directory.
# 3. Compile the main `sniffnet` binary, linking against the pre-compiled dependencies
#    and including any code generated by `build.rs`.
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







