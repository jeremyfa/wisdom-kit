# Builder image for the Linux packages (.deb and .rpm).
#
# The AppImage is built from a different image; see linux-appimage.Dockerfile
# for why the two cannot share one base.
#
# Ubuntu 22.04 is the OLDEST distribution that ships libwebkit2gtk-4.1-dev,
# which Tauri 2 requires. Building on the oldest supported base is the whole
# point: the bundled libraries are then compiled against this host's glibc,
# glib and HarfBuzz, so they reference only symbols that newer distributions
# also have. Build the same packages on a current Ubuntu and they install
# cleanly everywhere and then fail at startup on anything older with
# "symbol lookup error", a bug that never appears on the machine that built
# it.
#
# Both architectures use this one file: ubuntu:22.04 is multi-arch, and
# export-linux.sh passes --platform linux/amd64 or linux/arm64.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# These paths match the named volumes export-linux.sh mounts, so the cargo
# registry survives between runs and an incremental build is quick.
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH

# Tauri 2's Linux build dependencies, plus the packaging tools its bundlers
# shell out to (patchelf, desktop-file-utils, rpm).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libwebkit2gtk-4.1-dev \
        libsoup-3.0-dev \
        libgtk-3-dev \
        libxdo-dev \
        libssl-dev \
        libayatana-appindicator3-dev \
        librsvg2-dev \
        build-essential \
        pkg-config \
        curl wget file ca-certificates \
        xdg-utils \
        patchelf \
        desktop-file-utils \
        rpm \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 22.04's packaged Rust is far too old for current Tauri, so take the
# real stable channel from rustup. --no-modify-path because PATH is set above.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path

# The Tauri CLI as a Rust binary, baked into the image. This is what lets the
# container bundle without Node, npm or Haxe: the frontend was already built
# on the host and arrives through the bind mount.
RUN cargo install tauri-cli --version "^2.0.0" --locked

WORKDIR /workspace
