#!/bin/bash
# Shared plumbing for every export script.
#
# Sourced, never executed:
#     . "$(dirname "$0")/scripts/lib.sh"
#
# What it gives you:
#   - every name from project.config.sh, as a shell variable
#   - VERSION, read from package.json (the single source of truth)
#   - HOST_OS / HOST_ARCH, and `require_host` to refuse an impossible target
#     in one second instead of failing obscurely mid-build
#   - `need_cmd` for prerequisite checks that say how to install the thing
#   - `load_signing_env` for the gitignored .env.signing
#   - `artifact_name` so every script, on every host, produces identical names
#
# Nothing here prints unless something is wrong, so a successful build's output
# is the build's own.

# Only bash: the scripts use arrays and [[ ]].
if [ -z "${BASH_VERSION:-}" ]; then
    echo "error: these scripts require bash" >&2
    exit 1
fi

set -euo pipefail

# Two roots, and they are not the same directory any more.
#
#   KIT_DIR   this kit, wherever the project mounted it (usually
#             lib/wisdom-kit). Resolved from THIS file, so it is right however
#             the script was invoked.
#   ROOT_DIR  the project being built. Found by walking up from the working
#             directory looking for project.config.sh, which is what makes a
#             directory a project.
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_project_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/project.config.sh" ]; then
            printf '%s' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

ROOT_DIR="$(find_project_root)" || {
    echo "error: no project.config.sh found in $PWD or above it" >&2
    echo "  Run this from a project built on the kit, or through 'npm run'." >&2
    exit 1
}
cd "$ROOT_DIR"

BUNDLES_DIR="$ROOT_DIR/dist/bundles"

## Configuration

# The kit's own settings first, so a project can override any of them and
# never has to restate them.
# shellcheck source=/dev/null
. "$KIT_DIR/kit.config.sh"
# shellcheck source=/dev/null
. "$ROOT_DIR/project.config.sh"

# Derived names. A project states its slug, its product name, its identifier
# and its main class. The rest follows unless it deliberately says otherwise.
# scripts/config.mjs applies exactly the same defaults on the JavaScript side,
# and the two must never disagree.
: "${APP_SLUG:?APP_SLUG must be set in project.config.sh}"
: "${APP_PRODUCT_NAME:?APP_PRODUCT_NAME must be set in project.config.sh}"
: "${APP_IDENTIFIER:?APP_IDENTIFIER must be set in project.config.sh}"

APP_CRATE_NAME="${APP_CRATE_NAME:-$APP_SLUG}"
APP_LIB_NAME="${APP_LIB_NAME:-$(printf '%s' "$APP_SLUG" | tr '-' '_')_lib}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-$APP_SLUG}"
DOCKER_PREFIX="${DOCKER_PREFIX:-$APP_SLUG}"
APP_HAXE_PACKAGE="${APP_HAXE_PACKAGE:-app}"
APP_MAIN_CLASS="${APP_MAIN_CLASS:-app.Main}"
WEB_DEV_PORT="${WEB_DEV_PORT:-5173}"
ITCH_TARGET="${ITCH_TARGET:-}"
APP_ICON="${APP_ICON:-}"
APP_ICON_BACKGROUND="${APP_ICON_BACKGROUND:-#6366f1 #4338ca}"
APP_ICON_FOREGROUND="${APP_ICON_FOREGROUND:-#ffffff}"
APP_ICON_STROKE="${APP_ICON_STROKE:-2.25}"

# The version lives in package.json and nowhere else. Parsed rather than
# `node -p` so the export scripts keep working without node on PATH, which
# matters inside the minimal Linux build containers.
VERSION="$(grep -m1 '"version"' "$ROOT_DIR/package.json" | sed -E 's/.*"version" *: *"([^"]+)".*/\1/')"
if [ -z "$VERSION" ]; then
    echo "error: could not read \"version\" from package.json" >&2
    exit 1
fi

## Host

HOST_OS="$(uname -s)"      # Darwin | Linux | MINGW64_NT-… (git-bash on Windows)
HOST_ARCH="$(uname -m)"    # x86_64 | arm64 | aarch64

case "$HOST_OS" in
    Darwin)                 HOST=mac ;;
    Linux)                  HOST=linux ;;
    MINGW*|MSYS*|CYGWIN*)   HOST=windows ;;
    *)                      HOST=unknown ;;
esac

## Output

say()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

die() {
    printf 'error: %s\n' "$1" >&2
    shift
    for line in "$@"; do printf '  %s\n' "$line" >&2; done
    exit 1
}

## Guards

# require_host <target-name> <allowed host> [allowed host …]
#
# Stops in one second when this machine cannot build the requested target,
# and says why. Without it, a macOS build attempted on Linux fails deep inside
# cargo with a message about a missing SDK, minutes in.
require_host() {
    local target="$1"; shift
    local allowed=("$@")
    local host
    for host in "${allowed[@]}"; do
        [ "$HOST" = "$host" ] && return 0
    done
    die "$target cannot be built on this machine (host: $HOST)" \
        "Supported hosts for this target: ${allowed[*]}" \
        "" \
        "macOS bundles require macOS: the Apple toolchain, codesign and" \
        "notarytool have no equivalent elsewhere. Everything else can be" \
        "built from a Mac, and each target can also be built on its own OS."
}

# need_cmd <command> <how to install it> [more lines …]
need_cmd() {
    local cmd="$1"; shift
    command -v "$cmd" >/dev/null 2>&1 && return 0
    die "$cmd not found in PATH" "$@"
}

# rustup is installed outside the default PATH of a non-login shell often
# enough that every script would otherwise repeat this.
load_cargo_env() {
    if ! command -v rustup >/dev/null 2>&1 && [ -f "$HOME/.cargo/env" ]; then
        # shellcheck source=/dev/null
        . "$HOME/.cargo/env"
    fi
}

need_rustup() {
    load_cargo_env
    need_cmd rustup \
        "Install it with the official installer:" \
        "    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" \
        "" \
        "Then open a new terminal, or run: . \"\$HOME/.cargo/env\""
}

## Signing

# Load .env.signing into the environment, if it exists.
#
# `set -a` exports everything the file assigns, which is what tauri-bundler
# and notarytool read. The file is gitignored, and .env.signing.example documents
# each variable. Never echo these values.
load_signing_env() {
    if [ -f "$ROOT_DIR/.env.signing" ]; then
        set -a
        # shellcheck source=/dev/null
        . "$ROOT_DIR/.env.signing"
        set +a
    fi
}

# Fail now rather than after an hour of builds.
require_signing_identity() {
    load_signing_env
    if [ -z "${APPLE_SIGNING_IDENTITY:-}" ]; then
        die "APPLE_SIGNING_IDENTITY is not set" \
            "Copy .env.signing.example to .env.signing and fill it in," \
            "or set ALLOW_UNSIGNED=1 to produce a build you cannot distribute."
    fi
}

require_notarization_credentials() {
    load_signing_env
    local missing=()
    [ -z "${APPLE_SIGNING_IDENTITY:-}" ] && missing+=(APPLE_SIGNING_IDENTITY)
    [ -z "${APPLE_ID:-}" ]               && missing+=(APPLE_ID)
    [ -z "${APPLE_ID_PASSWORD:-}" ]      && missing+=(APPLE_ID_PASSWORD)
    [ -z "${APPLE_TEAM_ID:-}" ]          && missing+=(APPLE_TEAM_ID)
    if [ ${#missing[@]} -gt 0 ]; then
        die "missing notarization credentials: ${missing[*]}" \
            "See .env.signing.example. APPLE_ID_PASSWORD is an app-specific" \
            "password from appleid.apple.com, never the account password."
    fi
}

## Naming
#
# ONE definition of what a distributable is called, used by the mac, linux and
# windows scripts alike. That is what makes an artifact built on a CI runner
# indistinguishable from the same artifact built on a Mac, which in turn is
# what lets a release come from either route.
#
#     <prefix>-v<version>-<platform>-<arch>[-<variant>].<ext>

artifact_name() {
    local platform="$1" arch="$2" ext="$3" variant="${4:-}"
    if [ -n "$variant" ]; then
        printf '%s-v%s-%s-%s-%s.%s' "$ARTIFACT_PREFIX" "$VERSION" "$platform" "$arch" "$variant" "$ext"
    else
        printf '%s-v%s-%s-%s.%s' "$ARTIFACT_PREFIX" "$VERSION" "$platform" "$arch" "$ext"
    fi
}

## Build steps

ensure_bundles_dir() {
    mkdir -p "$BUNDLES_DIR"
}

# Verify the config, then push package.json's version into tauri.conf.json and
# Cargo.toml.
#
# This MUST happen before `tauri build`, and cannot be done from
# beforeBuildCommand: the Tauri CLI reads tauri.conf.json once when it starts,
# so a version written from inside the build would be picked up only by the
# NEXT build, and every bundle would ship stamped one release behind.
prepare_build() {
    need_cmd node "Install Node (see .nvmrc for the expected version)."
    # --release: refuse to ship a build of local checkouts (project.local.sh)
    # that are not exactly the pushed, recorded commits.
    node "$KIT_DIR/scripts/check-config.mjs" --release
    node "$KIT_DIR/scripts/sync-version.mjs"
}

# Build the frontend on the HOST, always.
#
# The Linux containers carry Rust and the GTK/WebKit headers, and deliberately
# not Haxe. dist/web is a bind mount, so what the host compiles is what the
# container bundles, and it is the identical directory a browser would be
# served, which is the point of having only one output.
# KIT_PREBUILT_FRONTEND=1 uses the dist/web already there instead: CI builds
# the frontend once and hands it to each desktop job, some of which run where
# Haxe has no release (Linux on ARM).
build_frontend() {
    if [ "${KIT_PREBUILT_FRONTEND:-0}" = "1" ]; then
        [ -f "$ROOT_DIR/dist/web/index.html" ] || die "KIT_PREBUILT_FRONTEND=1, but there is no dist/web/index.html"
        step "Using the prebuilt frontend in dist/web"
        return 0
    fi
    need_cmd npm "Install Node (see .nvmrc for the expected version)."
    step "Building frontend (haxe + tailwind) on the host"
    node "$KIT_DIR/cli.mjs" build --release
}

# Move a file if it exists, quietly. Tauri names bundles after productName,
# which gives "Wisdom App_0.1.0_amd64.deb". Every script renames to the
# convention above, and must not fail when a format was not produced.
rename_if_present() {
    local from="$1" to="$2"
    [ -f "$from" ] && mv -f "$from" "$to"
    return 0
}

# Copy a finished artifact into dist/bundles/ and report it.
publish_artifact() {
    local path="$1"
    [ -f "$path" ] || die "expected artifact not found: $path"
    ensure_bundles_dir
    cp -f "$path" "$BUNDLES_DIR/"
    say "  $(basename "$path")"
}
