# Settings that belong to the KIT, not to any project built on it.
#
# Sourced by scripts/lib.sh before the project's own project.config.sh, so a
# project can override any of these but never has to state them.

# Pinned Tauri CLI fork providing the sharun-based portable AppImage bundler
# (upstream PR #12491 plus a resource-copy fix). The stock bundler produces
# EGL_BAD_PARAMETER and a white screen on Steam Deck, Arch and Fedora.
#
# MUST match `ARG TAURI_CLI_REV` in docker/linux-appimage.Dockerfile;
# scripts/check-kit.mjs enforces that. Advance both together, rebuild the
# image, and smoke-test the AppImage on a non-Ubuntu distribution.
TAURI_CLI_FORK_URL="https://github.com/jeremyfa/tauri"
TAURI_CLI_FORK_REV="6f6b37ef2d7cccbd22f6d93ba1c9e8a25de00d1e"

# Port used by `npm run dev:web`.
WEB_DEV_PORT="5173"

# The Tauri plugins the kit registers in tauri/src/lib.rs.
#
# Every project must declare these as DIRECT dependencies in its
# src-tauri/Cargo.toml, because Tauri's ACL collects permission manifests
# through Cargo's `links` mechanism and that only reaches direct dependents.
# scripts/check-config.mjs compares the two lists. Add a plugin here, to
# tauri/src/lib.rs, to tauri/Cargo.toml, and tell projects to add the
# dependency line.
KIT_TAURI_PLUGINS="dialog fs opener clipboard-manager"
