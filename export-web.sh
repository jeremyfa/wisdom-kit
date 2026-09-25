#!/usr/bin/env bash
#
# Package the web build as a zip, ready to upload to any web host.
#
#     ./export-web.sh
#
# Runs on every host. The archive holds one folder, named like the other
# artifacts, with index.html inside: unzip it where the page should live, at
# the root of a site or in any folder below it, since every path in the page
# is relative.
#
# Output:
#   dist/bundles/<prefix>-v<version>-web.zip

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

prepare_build
build_frontend

need_cmd zip "Install zip, or package dist/web by hand."

ensure_bundles_dir
NAME="$ARTIFACT_PREFIX-v$VERSION-web"
STAGE="$BUNDLES_DIR/$NAME"

rm -rf "$STAGE" "$BUNDLES_DIR/$NAME.zip"
cp -R "$ROOT_DIR/dist/web" "$STAGE"
# Zipped from inside dist/bundles so the archive's single top-level entry is
# the folder name, not an absolute path.
( cd "$BUNDLES_DIR" && zip -qr "$NAME.zip" "$NAME" )
rm -rf "$STAGE"

step "Built v$VERSION for the web"
say "  $NAME.zip"
