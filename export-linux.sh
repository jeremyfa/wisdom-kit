#!/bin/bash
# Build the Linux distributables: .deb, .rpm and .AppImage.
#
#     ./export-linux.sh              # x64
#     ./export-linux.sh arm64
#     ./export-linux.sh x64 --native # Linux host of the same arch, no Docker
#
# Runs from macOS or from Linux. Not from Windows: there is no Linux toolchain
# there, and Docker Desktop's Linux containers on Windows are a different
# enough environment that pretending otherwise would only produce bundles
# nobody has tested.
#
# DOCKER IS THE DEFAULT ON EVERY HOST, Linux included. Two reasons:
#
#   Reproducibility. The base distribution is pinned, so the .deb and .rpm
#   cannot pick up glibc, glib or HarfBuzz symbols newer than the oldest
#   distribution we claim to support. Built natively on a current Ubuntu, they
#   install fine and then fail at startup on Debian with "symbol lookup error".
#
#   One code path. The AppImage needs a NEWER base than the packages do, so
#   there are two images either way. Maintaining a third, native variant would
#   double the surface for no gain.
#
# `--native` stays as an escape hatch for fast iteration on a Linux machine
# whose architecture already matches.
#
# On a Linux CI runner of the matching architecture, Docker emulates nothing:
# linux/amd64 on x64 and linux/arm64 on ARM both run natively, and the only
# cost is building the images once, which caches.
#
# Output (both paths, identical names):
#   dist/bundles/<prefix>-v<version>-linux-<arch>.AppImage
#   src-tauri/target/<triple>/release/bundle/{deb,rpm}/<prefix>-v<version>-linux-<arch>.{deb,rpm}

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

require_host "Linux bundles" mac linux

## Arguments

ARCH="x64"
NATIVE=0
for arg in "$@"; do
    case "$arg" in
        x64|amd64|x86_64)   ARCH=x64 ;;
        arm64|aarch64)      ARCH=arm64 ;;
        --native)           NATIVE=1 ;;
        *) die "unknown argument: $arg" "Usage: ./export-linux.sh [x64|arm64] [--native]" ;;
    esac
done

case "$ARCH" in
    x64)
        DOCKER_PLATFORM=linux/amd64
        RUST_TARGET=x86_64-unknown-linux-gnu
        DEB_ARCH=amd64 RPM_ARCH=x86_64 APPIMAGE_ARCH=amd64
        ;;
    arm64)
        DOCKER_PLATFORM=linux/arm64
        RUST_TARGET=aarch64-unknown-linux-gnu
        DEB_ARCH=arm64 RPM_ARCH=aarch64 APPIMAGE_ARCH=aarch64
        ;;
esac

if [ "$NATIVE" = "1" ]; then
    [ "$HOST" = "linux" ] || die "--native requires a Linux host (host: $HOST)"
    case "$HOST_ARCH:$ARCH" in
        x86_64:x64|aarch64:arm64) ;;
        *) die "--native cannot cross-compile: host is $HOST_ARCH, target is $ARCH" \
               "Drop --native to build the other architecture through Docker." ;;
    esac
fi

BUNDLE_DIR="$ROOT_DIR/src-tauri/target/$RUST_TARGET/release/bundle"
DEB_PATH="$BUNDLE_DIR/deb/$(artifact_name linux "$DEB_ARCH" deb)"
RPM_PATH="$BUNDLE_DIR/rpm/$(artifact_name linux "$RPM_ARCH" rpm)"
APPIMAGE_PATH="$BUNDLE_DIR/appimage/$(artifact_name linux "$APPIMAGE_ARCH" AppImage)"

prepare_build
build_frontend

## Docker lifecycle (macOS only)
#
# On a Mac the daemon lives in Docker Desktop, which may not be running. Start
# it if needed, and stop it afterwards only if we were the ones who started it.
# On Linux Docker is a system service and none of this applies.

DOCKER_STARTED_BY_US=0

stop_docker_if_we_started_it() {
    [ "$DOCKER_STARTED_BY_US" = "1" ] || return 0
    say ""
    say "Stopping Docker Desktop (this script started it)"
    if ! docker desktop stop >/dev/null 2>&1; then
        osascript -e 'quit app "Docker"' >/dev/null 2>&1 || true
    fi
}

start_docker_if_needed() {
    need_cmd docker "Install Docker Desktop:" "    https://www.docker.com/products/docker-desktop/"

    docker info >/dev/null 2>&1 && return 0

    if [ "$HOST" != "mac" ]; then
        die "the Docker daemon is not running" \
            "Start it, or pass --native to build without Docker."
    fi

    [ -d /Applications/Docker.app ] || die "Docker Desktop is not installed" \
        "    https://www.docker.com/products/docker-desktop/"

    # A previous run may have asked Docker to quit and its VM may still be
    # draining. `open -a Docker` would no-op against the dying process and we
    # would wait forever. Let the old one finish first.
    if pgrep -x Docker >/dev/null 2>&1; then
        printf 'Waiting for the previous Docker session to shut down'
        for _ in $(seq 1 60); do
            pgrep -x Docker >/dev/null 2>&1 || break
            printf '.'; sleep 1
        done
        printf '\n'
    fi

    say "Starting Docker Desktop"
    open -a Docker
    printf 'Waiting for the Docker daemon'
    for _ in $(seq 1 90); do
        if docker info >/dev/null 2>&1; then
            DOCKER_STARTED_BY_US=1
            printf ' ready\n'
            trap stop_docker_if_we_started_it EXIT
            return 0
        fi
        printf '.'; sleep 1
    done
    printf '\n'
    die "the Docker daemon did not become ready within 90 seconds"
}

## Build

# Pass 1 produces .deb and .rpm, pass 2 produces the .AppImage, from two
# different base distributions. beforeBuildCommand is overridden to nothing
# because the host already built the frontend, and dist/web is bind-mounted in.
CONFIG_OVERRIDE='{"build":{"beforeBuildCommand":""}}'

if [ "$NATIVE" = "1" ]; then

    need_rustup
    need_cmd cargo "Install Rust:" "    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"

    if ! pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
        die "Tauri's Linux build dependencies are missing" \
            "On Ubuntu or Debian:" \
            "    sudo apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev libgtk-3-dev \\" \
            "        libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev \\" \
            "        build-essential curl wget file patchelf"
    fi

    step "Building .deb and .rpm natively ($ARCH)"
    node "$KIT_DIR/cli.mjs" tauri build --target "$RUST_TARGET" --bundles deb,rpm

    # The AppImage needs the pinned fork, installed through cargo. The check
    # against `cargo install --list` makes re-runs a no-op once the right
    # revision is on disk. Without it every build would spend ten minutes
    # rebuilding the same CLI.
    if ! cargo install --list 2>/dev/null | grep -E '^tauri-cli ' | grep -q "${TAURI_CLI_FORK_REV:0:9}"; then
        step "Installing the pinned Tauri CLI fork (one-time, 5-10 minutes)"
        cargo install tauri-cli --git "$TAURI_CLI_FORK_URL" --rev "$TAURI_CLI_FORK_REV" --locked
    fi

    step "Building .AppImage natively ($ARCH)"
    # `cargo tauri`, not `npm run tauri`: the npm wrapper resolves to the
    # registry CLI and would quietly ignore the fork we just installed.
    TAURI_BUNDLER_NEW_APPIMAGE_FORMAT=true \
        cargo tauri build --target "$RUST_TARGET" --bundles appimage

else

    start_docker_if_needed

    DEB_IMAGE="${DOCKER_PREFIX}-linux-builder:${ARCH}"
    APPIMAGE_IMAGE="${DOCKER_PREFIX}-linux-appimage-builder:${ARCH}"

    step "Preparing the .deb/.rpm builder image ($ARCH)"
    docker build --platform "$DOCKER_PLATFORM" \
        -t "$DEB_IMAGE" -f "$KIT_DIR/docker/linux.Dockerfile" "$KIT_DIR/docker/"

    step "Building .deb and .rpm in Docker ($DOCKER_PLATFORM)"
    docker run --rm \
        --platform "$DOCKER_PLATFORM" \
        -v "$ROOT_DIR:/workspace" \
        -v "${DOCKER_PREFIX}-cargo-${ARCH}:/usr/local/cargo/registry" \
        -v "${DOCKER_PREFIX}-tauri-cache-${ARCH}:/root/.cache/tauri" \
        -w /workspace \
        -e APPIMAGE_EXTRACT_AND_RUN=1 \
        "$DEB_IMAGE" \
        cargo tauri build --target "$RUST_TARGET" --bundles deb,rpm --config "$CONFIG_OVERRIDE"

    step "Preparing the .AppImage builder image ($ARCH)"
    docker build --platform "$DOCKER_PLATFORM" \
        --build-arg "TAURI_CLI_REV=$TAURI_CLI_FORK_REV" \
        -t "$APPIMAGE_IMAGE" -f "$KIT_DIR/docker/linux-appimage.Dockerfile" "$KIT_DIR/docker/"

    step "Building .AppImage in Docker ($DOCKER_PLATFORM)"
    # Separate cache volumes: the two images carry different Tauri CLIs, and
    # sharing a registry would make each pass invalidate the other's.
    docker run --rm \
        --platform "$DOCKER_PLATFORM" \
        -v "$ROOT_DIR:/workspace" \
        -v "${DOCKER_PREFIX}-cargo-appimage-${ARCH}:/usr/local/cargo/registry" \
        -v "${DOCKER_PREFIX}-tauri-cache-appimage-${ARCH}:/root/.cache/tauri" \
        -w /workspace \
        -e APPIMAGE_EXTRACT_AND_RUN=1 \
        -e TAURI_BUNDLER_NEW_APPIMAGE_FORMAT=true \
        "$APPIMAGE_IMAGE" \
        cargo tauri build --target "$RUST_TARGET" --bundles appimage --config "$CONFIG_OVERRIDE"

    # The containers run as root, so on a Linux host what they wrote belongs
    # to root, and the renames below fail with "Permission denied". Docker
    # Desktop on macOS maps ownership back to the user, so only Linux needs
    # this. Done from a container, because only root may chown the files.
    if [ "$HOST" = "linux" ]; then
        docker run --rm --platform "$DOCKER_PLATFORM" -v "$ROOT_DIR:/workspace" "$APPIMAGE_IMAGE" \
            chown -R "$(id -u):$(id -g)" /workspace/src-tauri
    fi

fi

## Rename to the project convention
#
# Tauri names Linux bundles from productName, which has a space in it, and
# uses a different separator per format. One convention, applied here, keeps
# a locally built artifact byte-identical in name to a CI-built one.

rename_if_present "$BUNDLE_DIR/deb/${APP_PRODUCT_NAME}_${VERSION}_${DEB_ARCH}.deb" "$DEB_PATH"
rename_if_present "$BUNDLE_DIR/rpm/${APP_PRODUCT_NAME}-${VERSION}-1.${RPM_ARCH}.rpm" "$RPM_PATH"
rename_if_present "$BUNDLE_DIR/appimage/${APP_PRODUCT_NAME}_${VERSION}_${APPIMAGE_ARCH}.AppImage" "$APPIMAGE_PATH"

## AppImage regression check
#
# The sharun-based bundler is experimental and has regressed twice during
# integration: once dropping bundled resources, once dropping the
# tmp/<lib_id> symlink the launcher needs. Both produce an AppImage that
# builds cleanly and then shows a white screen on the user's machine. Check
# the load-bearing pieces here, where it costs a second.

if [ -f "$APPIMAGE_PATH" ]; then
    step "Checking the AppImage"
    EXTRACT_DIR="$(mktemp -d)"
    ( cd "$EXTRACT_DIR" && "$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1 ) || true

    if [ -d "$EXTRACT_DIR/squashfs-root" ]; then
        ROOT="$EXTRACT_DIR/squashfs-root"
        HOOK="$ROOT/bin/01-path-mapping-hardcoded.src.hook"
        LIB_ID="$(grep '_tmp_lib=' "$HOOK" 2>/dev/null | head -1 | cut -d= -f2 || true)"

        BINARY_OK=no
        [ -n "$(find "$ROOT" -name "$APP_CRATE_NAME" -type f 2>/dev/null | head -1)" ] && BINARY_OK=yes

        SYMLINK_OK=no
        [ -n "$LIB_ID" ] && [ -L "$ROOT/tmp/$LIB_ID" ] && SYMLINK_OK=yes

        WEBKIT_OK=no
        [ -n "$(find "$ROOT" -name 'libwebkit2gtk*' 2>/dev/null | head -1)" ] && WEBKIT_OK=yes

        say "  binary: $BINARY_OK   lib id: ${LIB_ID:-missing}   tmp symlink: $SYMLINK_OK   webkit: $WEBKIT_OK"

        if [ "$BINARY_OK" != yes ] || [ "$SYMLINK_OK" != yes ] || [ "$WEBKIT_OK" != yes ]; then
            rm -rf "$EXTRACT_DIR"
            die "the AppImage is missing load-bearing pieces" \
                "It would build, ship, and then show a white screen." \
                "Check the pinned Tauri CLI revision in project.config.sh."
        fi
    else
        warn "could not extract the AppImage to check it"
    fi
    rm -rf "$EXTRACT_DIR"
fi

step "Built v$VERSION for linux-$ARCH"
[ -f "$DEB_PATH" ] && say "  deb: $DEB_PATH"
[ -f "$RPM_PATH" ] && say "  rpm: $RPM_PATH"
publish_artifact "$APPIMAGE_PATH"

say ""
say "The .deb and .rpm stay at their build paths; only the AppImage, which is"
say "the portable one, is copied into dist/bundles/."
say ""
say "Before publishing, smoke-test the AppImage on a non-Ubuntu distribution"
say "(Fedora, Arch or a Steam Deck). It must open its window with no"
say "EGL_BAD_PARAMETER in the log and no blank screen."
