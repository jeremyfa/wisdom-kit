# What this project is called. Everything else is derived.
#
# Read by the kit through scripts/config.mjs and scripts/lib.sh, which apply
# the same defaults on both sides. `npm run check-config` fails if any file
# disagrees with what is here.

# npm package name and artifact filename prefix. kebab-case, no spaces.
# Also becomes the Rust crate name and the Docker image prefix unless
# APP_CRATE_NAME or DOCKER_PREFIX say otherwise.
APP_SLUG="wisdom-app"

# Human-facing name. Drives the Tauri productName, the .app bundle name, the
# window title, and the macOS /Volumes/<name> mount point during DMG builds.
APP_PRODUCT_NAME="Wisdom App"

# Reverse-DNS bundle identifier: macOS bundle id, Windows registry key, Linux
# .desktop id, and the per-user data directory name on every platform.
#
# CHANGE THIS BEFORE SHIPPING. Getting it wrong is invisible until release,
# then it collides in the macOS Launch Services database and the Windows
# registry, and changing it later orphans every user's settings.
APP_IDENTIFIER="com.example.wisdomapp"

# Haxe entry point. The kit is always the `kit` package; this is yours.
APP_MAIN_CLASS="app.Main"

# Optional, all derived from APP_SLUG when left out:
#   APP_CRATE_NAME    Cargo [package].name           (default: the slug)
#   APP_LIB_NAME      Cargo [lib].name               (default: slug_with_underscores_lib)
#   ARTIFACT_PREFIX   <prefix>-v<version>-<os>.<ext> (default: the slug)
#   DOCKER_PREFIX     builder image and cache names  (default: the slug)
#   APP_HAXE_PACKAGE  your Haxe package              (default: app)
#   WEB_DEV_PORT      npm run dev:web                (default: 5173)

# Optional itch.io target "<user>/<project>" for `npm run publish-itchio`.
# Empty disables publishing with a helpful message rather than a failure.
ITCH_TARGET=""
