#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
mkdir -p build/Glint.app/Contents/MacOS build/Glint.app/Contents/Resources
cp "$binary_dir/Glint" build/Glint.app/Contents/MacOS/Glint
cp Resources/Info.plist build/Glint.app/Contents/Info.plist
cp Resources/Glint.icns build/Glint.app/Contents/Resources/Glint.icns
codesign --force --sign - build/Glint.app
printf 'Built %s/build/Glint.app\n' "$PWD"
