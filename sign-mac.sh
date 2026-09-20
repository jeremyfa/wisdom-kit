#!/bin/bash
# Notarize and staple the macOS bundle produced by ./export-mac.sh.
#
# The .app and .dmg are ALREADY signed when they come out of the build, because
# export-mac.sh puts APPLE_SIGNING_IDENTITY in the environment and
# tauri-bundler signs with the hardened runtime and the entitlements file. So
# this script only walks Apple's notary service:
#
#   1. notarize a zip of the .app and wait for the verdict
#   2. staple the ticket to the .app
#   3. notarize the .dmg
#   4. staple the .dmg
#   5. VERIFY the staples actually took
#
# Step 5 is not ceremony. `stapler staple` can report success while Gatekeeper
# still refuses the bundle, and the only place that shows up otherwise is on a
# user's machine, at first launch, as "the app is damaged".
#
# Credentials come from .env.signing (gitignored) or the environment. In CI
# they are GitHub secrets. See .env.signing.example.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

require_host "macOS notarization" mac
require_notarization_credentials

need_cmd xcrun "Install Xcode command line tools:" "    xcode-select --install"

for vol in "/Volumes/$APP_PRODUCT_NAME"*; do
    [ -d "$vol" ] && hdiutil detach "$vol" -force >/dev/null 2>&1 || true
done

BUNDLE_DIR="$ROOT_DIR/src-tauri/target/universal-apple-darwin/release/bundle"
APP_PATH="$BUNDLE_DIR/macos/$APP_PRODUCT_NAME.app"
DMG_PATH="$BUNDLE_DIR/dmg/$(artifact_name mac universal dmg)"

[ -d "$APP_PATH" ] || die "$APP_PATH not found" "Run ./export-mac.sh first."
[ -f "$DMG_PATH" ] || die "$DMG_PATH not found" "Run ./export-mac.sh first."

notarize() {
    xcrun notarytool submit "$1" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait --timeout 30m
}

step "[1/5] Notarizing the app"
ZIP_PATH="$BUNDLE_DIR/$ARTIFACT_PREFIX-app.zip"
rm -f "$ZIP_PATH"
# ditto, not zip: it preserves resource forks and symlinks inside the bundle,
# which a plain zip mangles and the notary service then rejects.
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
notarize "$ZIP_PATH"
rm -f "$ZIP_PATH"

step "[2/5] Stapling the app"
xcrun stapler staple "$APP_PATH"

step "[3/5] Notarizing the disk image"
notarize "$DMG_PATH"

step "[4/5] Stapling the disk image"
xcrun stapler staple "$DMG_PATH"

step "[5/5] Verifying"
# `stapler validate` checks the ticket is attached. `spctl` asks the question
# the user's machine will actually ask at first launch. Both must pass.
xcrun stapler validate "$APP_PATH"
xcrun stapler validate "$DMG_PATH"

if ! spctl --assess --type execute --verbose=2 "$APP_PATH" 2>&1 | grep -q 'accepted'; then
    die "Gatekeeper rejected the notarized app" \
        "The staple reported success but the system still refuses the bundle." \
        "Inspect it with:" \
        "    spctl --assess --type execute --verbose=4 \"$APP_PATH\"" \
        "    codesign --verify --deep --strict --verbose=4 \"$APP_PATH\""
fi

step "Notarized and stapled v$VERSION"
publish_artifact "$DMG_PATH"
