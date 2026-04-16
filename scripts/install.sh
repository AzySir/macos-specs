#!/usr/bin/env bash
#
# MacOSSpecs installer — clones, builds, installs, cleans up.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AzySir/macos-specs/main/scripts/install.sh | bash
# Or, from inside a local checkout:
#   ./scripts/install.sh
#
set -euo pipefail

APP_NAME="MacOSSpecs"
REPO_URL="https://github.com/AzySir/macos-specs.git"
INSTALL_DIR="/Applications"
CLI_LINK="/usr/local/bin/macos-specs"

echo "MacOSSpecs installer"
echo "--------------------"

# --- Safety gates ---
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: MacOSSpecs only runs on macOS." >&2
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: 'git' is required." >&2
    exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
    echo "ERROR: Xcode Command Line Tools are required." >&2
    echo "       Run: xcode-select --install" >&2
    echo "       Then re-run this installer." >&2
    exit 1
fi

# --- Locate source tree ---
# If we're already inside a checkout, reuse it. Otherwise shallow-clone
# into a temp dir and wipe it when we're done — so nothing stays behind.
CLEANUP_DIR=""
if [[ -f "Package.swift" && -d "Sources/MacOSSpecs" ]]; then
    WORK_DIR="$PWD"
    echo "→ Using existing checkout at $WORK_DIR"
else
    WORK_DIR="$(mktemp -d -t macos-specs-install.XXXXXX)"
    CLEANUP_DIR="$WORK_DIR"
    echo "→ Cloning source into $WORK_DIR  (will be removed after install)"
    git clone --depth 1 "$REPO_URL" "$WORK_DIR" >/dev/null
fi

cleanup() {
    if [[ -n "$CLEANUP_DIR" && -d "$CLEANUP_DIR" ]]; then
        rm -rf "$CLEANUP_DIR"
    fi
}
trap cleanup EXIT

cd "$WORK_DIR"

# --- Build ---
echo "→ Building from source"
./scripts/build-app.sh

# --- Install the .app ---
echo "→ Installing $APP_NAME.app into $INSTALL_DIR"
if [[ -d "$INSTALL_DIR/$APP_NAME.app" ]]; then
    if ! rm -rf "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null; then
        sudo rm -rf "$INSTALL_DIR/$APP_NAME.app"
    fi
fi
if ! cp -R "build/$APP_NAME.app" "$INSTALL_DIR/" 2>/dev/null; then
    echo "  (admin privileges required to write to $INSTALL_DIR)"
    sudo cp -R "build/$APP_NAME.app" "$INSTALL_DIR/"
fi

# Ad-hoc signed → remove quarantine so Gatekeeper lets it launch.
echo "→ Removing quarantine attribute"
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

# --- CLI launcher shim at /usr/local/bin/macos-specs ---
echo "→ Installing CLI launcher at $CLI_LINK"
CLI_DIR="$(dirname "$CLI_LINK")"
if [[ ! -d "$CLI_DIR" ]]; then
    sudo mkdir -p "$CLI_DIR"
fi
SHIM='#!/usr/bin/env bash
open -a "'"$APP_NAME"'" "$@"'
if ! printf '%s\n' "$SHIM" > "$CLI_LINK" 2>/dev/null; then
    printf '%s\n' "$SHIM" | sudo tee "$CLI_LINK" >/dev/null
    sudo chmod +x "$CLI_LINK"
else
    chmod +x "$CLI_LINK"
fi

# --- Launch ---
echo "→ Launching $APP_NAME"
open -a "$APP_NAME"

cat <<EOF

✓ Installed.
  • Menu bar: look for the live metrics in your status bar.
  • CLI:      run 'macos-specs' in any terminal to open the app.
  • Launch-at-login: enabled automatically on first run (toggle off in the gear menu).
  • Accessibility: on first launch you'll be prompted to grant Accessibility access
    in System Settings. This allows the Activity Monitor tab-switch shortcut to work.

Uninstall:
  rm -rf "$INSTALL_DIR/$APP_NAME.app" && sudo rm -f "$CLI_LINK"
EOF
