#!/bin/bash
# Push the artifacts in dist/bundles/ to itch.io with butler.
#
#     ./publish-itchio.sh                 everything in dist/bundles
#     ./publish-itchio.sh mac linux       only those channels
#
# DISABLED BY DEFAULT. ITCH_TARGET in project.config.sh is empty, and this
# script says so and stops rather than failing somewhere in the middle. Set it
# to "<user>/<project>" to turn publishing on. It is deliberately not filled in
# for you: an account name is the kind of thing that should never arrive in a
# repository by accident.
#
# Authentication is butler's own: run `butler login` once, or put an API key in
# BUTLER_API_KEY. No credential is read from this repository.
#
# Channel names follow itch.io's convention, because that is what its launcher
# uses to decide which download a given visitor is offered.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

if [ -z "${ITCH_TARGET:-}" ]; then
    say "Publishing to itch.io is not configured."
    say ""
    say "Set ITCH_TARGET in project.config.sh to your \"<user>/<project>\" page,"
    say "for example:"
    say ""
    say '    ITCH_TARGET="acme/my-app"'
    say ""
    say "Then install butler (https://itch.io/docs/butler/) and run"
    say "'butler login' once."
    exit 0
fi

need_cmd butler \
    "Install it from https://itch.io/docs/butler/" \
    "    brew install butler          # macOS" \
    "" \
    "Then authenticate once with: butler login"

[ -d "$BUNDLES_DIR" ] || die "dist/bundles is empty" "Run ./export-all.sh first."

# channel -> the artifact that belongs on it
declare -a CHANNELS=(
    "osx-universal:$(artifact_name mac universal dmg)"
    "linux-amd64:$(artifact_name linux amd64 AppImage)"
    "linux-arm64:$(artifact_name linux aarch64 AppImage)"
    "windows:$(artifact_name windows x64 exe setup)"
    "windows-portable:$(artifact_name windows x64 zip portable)"
)

WANTED=("$@")
matches() {
    [ ${#WANTED[@]} -eq 0 ] && return 0
    local channel="$1" want
    for want in "${WANTED[@]}"; do
        case "$channel" in *"$want"*) return 0 ;; esac
    done
    return 1
}

PUSHED=0
MISSING=()

for entry in "${CHANNELS[@]}"; do
    channel="${entry%%:*}"
    file="${entry#*:}"
    matches "$channel" || continue

    if [ ! -f "$BUNDLES_DIR/$file" ]; then
        MISSING+=("$channel ($file)")
        continue
    fi

    step "Pushing $file to $ITCH_TARGET:$channel"
    butler push "$BUNDLES_DIR/$file" "$ITCH_TARGET:$channel" --userversion "$VERSION"
    PUSHED=$((PUSHED + 1))
done

step "Pushed $PUSHED artifact(s) as v$VERSION"

if [ ${#MISSING[@]} -gt 0 ]; then
    say ""
    say "Not present in dist/bundles, so not pushed:"
    for channel in "${MISSING[@]}"; do say "  $channel"; done
    say ""
    say "That is expected when you exported only some platforms. Run"
    say "./export-all.sh for a complete set."
fi
