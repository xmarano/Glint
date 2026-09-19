#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Only known generated products are removed. Refuse redirected output directories
# rather than risk deleting files outside this project through a symlink.
if [[ -L .build || -L build || -L build/Glint.app ]]; then
    printf '%s\n' 'Refusing to clean symlinked build locations. Inspect them manually.' >&2
    exit 1
fi

swift package clean
if [[ -e build/Glint.app ]]; then
    rm -rf -- build/Glint.app
fi
printf '%s\n' 'Cleaned Swift build products and build/Glint.app. Source assets and preview images were preserved.'
