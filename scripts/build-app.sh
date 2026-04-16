#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacOSSpecs"
APP_DIR="$ROOT/build/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

cd "$ROOT"

echo "→ Compiling Swift sources"
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find Sources/MacOSSpecs -name '*.swift' -type f)
if [[ ${#SOURCES[@]} -eq 0 ]]; then
    echo "No Swift sources found in Sources/MacOSSpecs" >&2
    exit 1
fi

mkdir -p build
swiftc \
    -O \
    -target arm64-apple-macos13 \
    -parse-as-library \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -framework IOKit \
    -framework Foundation \
    -framework ServiceManagement \
    -o "build/$APP_NAME" \
    "${SOURCES[@]}"

echo "→ Bundling $APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR"

mv "build/$APP_NAME" "$BIN_DIR/$APP_NAME"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "→ Ad-hoc codesign"
codesign --force --deep --sign - "$APP_DIR"

echo "✓ Built: $APP_DIR"
