#!/bin/bash
# Build the Windows distributables: an NSIS installer and a portable zip.
#
#     ./export-windows.sh
#
# Runs on Windows (in Git Bash) with the native MSVC toolchain, and on macOS
# or Linux through cargo-xwin. The two routes produce identically named
# artifacts, which is what lets a release come either from a Mac or from a
# Windows CI runner.
#
# Native is preferred where available: cargo-xwin has to download about 1.5 GB
# of MSVC SDK headers and libraries on first use, and a machine that already
# has Visual Studio Build Tools has them.
#
# MSI is deliberately not produced. Its bundler needs WiX, which is Windows
# only, so an MSI could never come out of the Mac route and the two hosts
# would stop being interchangeable.
#
# Output:
#   dist/bundles/<prefix>-v<version>-windows-x64-setup.exe
#   dist/bundles/<prefix>-v<version>-windows-x64-portable.zip

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

require_host "Windows bundles" mac linux windows

RUST_TARGET=x86_64-pc-windows-msvc

need_rustup
rustup target add "$RUST_TARGET" >/dev/null

prepare_build
build_frontend

if [ "$HOST" = "windows" ]; then

    # The MSVC linker comes from Visual Studio Build Tools. Without it the
    # failure is a bare "link.exe not found" from cargo, several minutes in.
    if ! command -v link >/dev/null 2>&1 && [ -z "${VCINSTALLDIR:-}" ]; then
        warn "the MSVC toolchain does not look like it is on PATH"
        warn "if the build fails at the link step, run this from a"
        warn "\"x64 Native Tools Command Prompt\", or install Visual Studio"
        warn "Build Tools with the \"Desktop development with C++\" workload"
    fi

    step "Building for Windows with the native MSVC toolchain"
    node "$KIT_DIR/cli.mjs" tauri build --target "$RUST_TARGET" --bundles nsis

else

    need_cmd cargo-xwin \
        "Install it with:" \
        "    cargo install --locked cargo-xwin" \
        "" \
        "The first Windows build then downloads about 1.5 GB of MSVC SDK" \
        "headers and libraries into ~/.cache/xwin. Cached afterwards."

    need_cmd makensis \
        "Install NSIS, which assembles the installer:" \
        "    brew install makensis        # macOS" \
        "    sudo apt install nsis        # Debian or Ubuntu"

    # cargo-xwin drives llvm-rc and llvm-dlltool. Homebrew's llvm is keg-only,
    # so it is not on PATH, and cargo-xwin finds it at the keg path by itself,
    # which is why those two locations count as present.
    if ! command -v llvm-rc >/dev/null 2>&1 \
        && [ ! -x /opt/homebrew/opt/llvm/bin/llvm-rc ] \
        && [ ! -x /usr/local/opt/llvm/bin/llvm-rc ]; then
        die "LLVM tooling (llvm-rc, llvm-dlltool) not found" \
            "    brew install llvm            # macOS" \
            "    sudo apt install llvm        # Debian or Ubuntu"
    fi

    step "Cross-building for Windows with cargo-xwin"
    # bundle.targets is overridden through --config rather than --bundles:
    # the CLI validates --bundles against the HOST operating system, not the
    # --target triple, so `--bundles nsis` is rejected outright from a Mac.
    node "$KIT_DIR/cli.mjs" tauri build \
        --runner cargo-xwin \
        --target "$RUST_TARGET" \
        --config '{"bundle":{"targets":["nsis"]}}'

fi

## Rename to the project convention

NSIS_DIR="$ROOT_DIR/src-tauri/target/$RUST_TARGET/release/bundle/nsis"
NSIS_PATH="$NSIS_DIR/$(artifact_name windows x64 exe setup)"
rename_if_present "$NSIS_DIR/${APP_PRODUCT_NAME}_${VERSION}_x64-setup.exe" "$NSIS_PATH"

## Portable zip
#
# The same executable the installer would place, in a folder the user can
# unzip anywhere. Everything this app needs at runtime is compiled into the
# binary, because the frontend is embedded from dist/web, so the portable
# bundle is genuinely just the .exe.
#
# Two things to tell users, and they are in the README:
#   - it needs the WebView2 runtime, which Windows 11 has and most Windows 10
#     machines have through Edge. The installer fetches it when missing. A zip
#     cannot.
#   - settings still go to the user's AppData directory. This is "runs without
#     installing", not "leaves no trace".

RAW_EXE="$ROOT_DIR/src-tauri/target/$RUST_TARGET/release/${APP_CRATE_NAME}.exe"
[ -f "$RAW_EXE" ] || die "built executable not found: $RAW_EXE"

ensure_bundles_dir
PORTABLE_NAME="$(artifact_name windows x64 zip portable)"
PORTABLE_NAME="${PORTABLE_NAME%.zip}"
PORTABLE_DIR="$BUNDLES_DIR/$PORTABLE_NAME"

rm -rf "$PORTABLE_DIR" "$BUNDLES_DIR/$PORTABLE_NAME.zip"
mkdir -p "$PORTABLE_DIR"
cp "$RAW_EXE" "$PORTABLE_DIR/${APP_PRODUCT_NAME}.exe"

need_cmd zip "Install zip, or build the portable bundle on another host."
# Zipped from inside dist/bundles so the archive's single top-level entry is
# the folder name, not an absolute path.
( cd "$BUNDLES_DIR" && zip -qr "$PORTABLE_NAME.zip" "$PORTABLE_NAME" )
rm -rf "$PORTABLE_DIR"

step "Built v$VERSION for windows-x64"
publish_artifact "$NSIS_PATH"
say "  $PORTABLE_NAME.zip"

say ""
say "Neither artifact is code-signed, so Windows SmartScreen will warn on"
say "first launch. Signing needs an EV certificate from a commercial"
say "authority; see the README."
