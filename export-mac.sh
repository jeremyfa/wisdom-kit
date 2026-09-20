#!/bin/bash
# Build a universal (Apple Silicon + Intel) macOS bundle.
#
#     ./export-mac.sh                 signed, ready for ./sign-mac.sh
#     ALLOW_UNSIGNED=1 ./export-mac.sh   no certificate needed, NOT distributable
#
# macOS only, and the only target that is: codesign, the Apple SDK and
# notarytool exist nowhere else. The reverse does not hold: this machine can
# also build Linux and Windows, which is what ./export-all.sh does.
#
# Signing happens DURING the build. tauri-bundler reads APPLE_SIGNING_IDENTITY
# from the environment when bundle.macOS.signingIdentity is absent from
# tauri.conf.json, so a single `tauri build` produces a signed .app inside a
# signed .dmg. ./sign-mac.sh then only has to notarize and staple.
#
# Output:
#   src-tauri/target/universal-apple-darwin/release/bundle/macos/<name>.app
#   dist/bundles/<prefix>-v<version>-mac-universal.dmg

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

require_host "macOS bundles" mac

need_rustup
# Idempotent: no-ops when the targets are already installed.
rustup target add aarch64-apple-darwin >/dev/null
rustup target add x86_64-apple-darwin >/dev/null

if [ "${ALLOW_UNSIGNED:-0}" = "1" ]; then
    warn "ALLOW_UNSIGNED=1, so the result will not be distributable"
    unset APPLE_SIGNING_IDENTITY || true
else
    require_signing_identity
fi

# Detach any stale volume from an aborted run or from the user having
# double-clicked a previous DMG. Tauri's DMG step mounts a volume named after
# productName and collides with one already mounted. The glob also catches the
# "<name> 1", "<name> 2" duplicates macOS appends on a name conflict.
for vol in "/Volumes/$APP_PRODUCT_NAME"*; do
    [ -d "$vol" ] && hdiutil detach "$vol" -force >/dev/null 2>&1 || true
done

prepare_build
build_frontend

step "Building universal macOS bundle"
node "$KIT_DIR/cli.mjs" tauri build --target universal-apple-darwin

BUNDLE_DIR="$ROOT_DIR/src-tauri/target/universal-apple-darwin/release/bundle"
APP_PATH="$BUNDLE_DIR/macos/$APP_PRODUCT_NAME.app"
DMG_DIR="$BUNDLE_DIR/dmg"
DMG_PATH="$DMG_DIR/$(artifact_name mac universal dmg)"

# Tauri names the .dmg after productName, which contains spaces. Rename to the
# project convention so an artifact built here and one built by CI are the
# same file name. The .app keeps its spaces: that is the Finder convention and
# what the user sees in Applications.
rename_if_present "$DMG_DIR/${APP_PRODUCT_NAME}_${VERSION}_universal.dmg" "$DMG_PATH"

[ -d "$APP_PATH" ] || die "expected app bundle not found: $APP_PATH"

step "Built v$VERSION"
say "  app: $APP_PATH"
publish_artifact "$DMG_PATH"

if [ "${ALLOW_UNSIGNED:-0}" = "1" ]; then
    say ""
    say "This build is unsigned. macOS will refuse to open it on any machine"
    say "but this one. Build with a certificate, then run ./sign-mac.sh, to"
    say "produce something you can hand to someone else."
else
    say ""
    say "Next: ./sign-mac.sh to notarize and staple."
fi
