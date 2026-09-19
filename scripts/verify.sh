#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# No publishing, installation, icon regeneration, or live requests by default.
# GLINT_LIVE_TESTS=1 explicitly opts into the existing provider acceptance test.
bash -n scripts/build.sh scripts/test.sh scripts/build-icon.sh scripts/clean.sh scripts/verify.sh
plutil -lint Resources/Info.plist Glint.xcodeproj/project.pbxproj
bash scripts/build.sh
bash scripts/test.sh
codesign --verify --strict build/Glint.app
printf '%s\n' 'Verification passed: script/project syntax, release build, tests, and app signature.'
