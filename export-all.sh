#!/bin/bash
# Build everything this machine can build, in one command.
#
#     ./export-all.sh                      everything
#     ./export-all.sh --no-sign            skip notarization
#     ./export-all.sh --only mac,windows   a subset
#
# From a Mac this covers all three operating systems and takes about an hour,
# most of it waiting on Apple's notary service. That is the point: one person,
# one machine, a complete release.
#
# From Linux it builds the Linux and Windows targets and says plainly that it
# skipped macOS. From Windows, the Windows targets. The same scripts are what
# CI runs, one target per matching runner, so a release can come from either
# route and the artifacts carry the same names.
#
# Credentials are checked FIRST. A missing .env.signing should cost a second,
# not an hour of builds followed by a failure at the last step.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

## Arguments

SIGN=1
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --no-sign) SIGN=0 ;;
        --only) shift; ONLY="${1:-}" ;;
        --only=*) ONLY="${1#--only=}" ;;
        *) die "unknown argument: $1" \
               "Usage: ./export-all.sh [--no-sign] [--only mac,linux,windows,web]" ;;
    esac
    shift
done

wants() {
    [ -z "$ONLY" ] && return 0
    case ",$ONLY," in *",$1,"*) return 0 ;; esac
    return 1
}

## What this host can do

DO_MAC=0 DO_LINUX=0 DO_WINDOWS=0
SKIPPED=()

if wants mac; then
    if [ "$HOST" = "mac" ]; then DO_MAC=1
    else SKIPPED+=("macOS: needs a Mac, because codesign and the Apple SDK exist nowhere else"); fi
fi

if wants linux; then
    if [ "$HOST" = "mac" ] || [ "$HOST" = "linux" ]; then DO_LINUX=1
    else SKIPPED+=("Linux: needs macOS or Linux with Docker"); fi
fi

if wants windows; then
    DO_WINDOWS=1
fi

# Every host can package the web build.
DO_WEB=0
if wants web; then DO_WEB=1; fi

if [ "$DO_MAC$DO_LINUX$DO_WINDOWS$DO_WEB" = "0000" ]; then
    die "nothing to build on this host ($HOST) with --only '$ONLY'"
fi

## Preflight
#
# Everything that can be verified without building is verified now.

prepare_build

if [ "$DO_MAC" = "1" ]; then
    if [ "${ALLOW_UNSIGNED:-0}" = "1" ]; then
        warn "ALLOW_UNSIGNED=1, so the macOS build will not be distributable"
        SIGN=0
    elif [ "$SIGN" = "1" ]; then
        require_notarization_credentials
    else
        require_signing_identity
    fi
fi

if [ "$DO_LINUX" = "1" ] && ! command -v docker >/dev/null 2>&1; then
    die "docker not found, and the Linux bundles need it" \
        "Install Docker Desktop, or re-run with --only mac,windows."
fi

## Run
#
# dist/bundles is wiped, because this command means "produce a release" and
# stale artifacts from a previous version silently riding along in the folder
# you upload from is exactly the mistake worth designing out. The individual
# export scripts do not wipe, so iterating on one platform accumulates.

rm -rf "$BUNDLES_DIR"
ensure_bundles_dir

TASKS=()
[ "$DO_MAC" = "1" ]     && TASKS+=("macOS universal")
[ "$DO_MAC" = "1" ] && [ "$SIGN" = "1" ] && TASKS+=("macOS notarization")
[ "$DO_LINUX" = "1" ]   && TASKS+=("Linux arm64" "Linux x64")
[ "$DO_WINDOWS" = "1" ] && TASKS+=("Windows x64")
[ "$DO_WEB" = "1" ]     && TASKS+=("Web")

TOTAL=${#TASKS[@]}
INDEX=0
next() { INDEX=$((INDEX + 1)); step "[$INDEX/$TOTAL] $1"; }

say "Exporting $APP_PRODUCT_NAME v$VERSION from $HOST"
say "Artifacts will be collected in dist/bundles/"
[ "$HOST" = "mac" ] && [ -z "$ONLY" ] && say "Expect about an hour, most of it waiting on Apple's notary service."

if [ "$DO_MAC" = "1" ]; then
    next "macOS universal"
    ./export-mac.sh
    if [ "$SIGN" = "1" ]; then
        next "macOS notarization"
        ./sign-mac.sh
    fi
fi

if [ "$DO_LINUX" = "1" ]; then
    next "Linux arm64"
    ./export-linux.sh arm64
    next "Linux x64"
    ./export-linux.sh x64
fi

if [ "$DO_WINDOWS" = "1" ]; then
    next "Windows x64"
    ./export-windows.sh
fi

if [ "$DO_WEB" = "1" ]; then
    next "Web"
    ./export-web.sh
fi

## Report

step "Done: $APP_PRODUCT_NAME v$VERSION"
for file in "$BUNDLES_DIR"/*; do
    [ -e "$file" ] || continue
    printf '  %-52s %s\n' "$(basename "$file")" "$(du -h "$file" | cut -f1)"
done

if [ ${#SKIPPED[@]} -gt 0 ]; then
    say ""
    say "Not built on this host:"
    for reason in "${SKIPPED[@]}"; do say "  $reason"; done
    say ""
    say "A tagged release builds each target on its own runner; see"
    say ".github/workflows/release.yml."
fi

if [ "$DO_MAC" = "1" ] && [ "$SIGN" = "0" ]; then
    say ""
    say "The macOS build was not notarized. It will not open on another Mac."
fi

say ""
say "The .deb and .rpm are not copied here; find them under"
say "src-tauri/target/*/release/bundle/."
