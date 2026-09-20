# Builder image for the portable AppImage.
#
# WHY A SECOND IMAGE
#
# Tauri 2's stock AppImage bundler embeds WebKitGTK and libEGL in a way that
# breaks on most non-Ubuntu hosts: Steam Deck, Arch and Fedora all come up
# with "Could not create default EGL display: EGL_BAD_PARAMETER" and a white
# window. The fix is the sharun-based bundler from Tauri PR #12491, which
# bundles libraries explicitly instead, and which the PR's contributors build
# on a recent base.
#
# WHY THE PACKAGES KEEP THE OLD BASE
#
# The .deb and .rpm are built on Ubuntu 22.04 (see linux.Dockerfile) so their
# symbol versions stay low enough to install on older distributions. The
# sharun AppImage solves portability a different way, by carrying its own
# libraries, so it does not need an old base and is better off without one.
#
# THE PIN
#
# TAURI_CLI_REV is a specific commit, never a branch head, so an image rebuild
# cannot silently change what ships. The same revision appears in
# kit.config.sh as TAURI_CLI_FORK_REV, and scripts/check-kit.mjs fails
# the build if the two disagree. To move the pin: verify a commit, update both
# places, rebuild the image, and smoke-test the AppImage on a non-Ubuntu
# distribution before releasing.
#
# The fork carries one patch over the upstream PR: the sharun bundler does not
# copy the resources directory into the AppDir, so bundle.resources entries
# silently vanish. When upstream takes the fix, point TAURI_CLI_URL back at
# tauri-apps/tauri.

FROM ubuntu:25.04

ENV DEBIAN_FRONTEND=noninteractive

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH

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
        zsync \
        squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path

# Keep these two in step with kit.config.sh. Docker invalidates the layer
# below when either ARG changes, so a new pin rebuilds the CLI.
ARG TAURI_CLI_URL=https://github.com/jeremyfa/tauri
ARG TAURI_CLI_REV=6f6b37ef2d7cccbd22f6d93ba1c9e8a25de00d1e
RUN cargo install tauri-cli --git $TAURI_CLI_URL --rev $TAURI_CLI_REV --locked

WORKDIR /workspace
