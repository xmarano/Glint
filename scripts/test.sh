#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
developer_dir="$(xcode-select -p)"
if [[ "$developer_dir" == */CommandLineTools ]]; then
    # Some CLT distributions bundle Swift Testing but SwiftPM omits its framework path.
    frameworks="$developer_dir/Library/Developer/Frameworks"
    # Swift 6.4 CLT also ships TestingMacros outside the default plugin lookup.
    testing_plugins="$developer_dir/usr/lib/swift/host/plugins/testing"
    plugin_flags=()
    if [[ -f "$testing_plugins/libTestingMacros.dylib" ]]; then
        plugin_flags=(-Xswiftc -plugin-path -Xswiftc "$testing_plugins")
    fi
    swift test --disable-xctest \
        -Xswiftc -F -Xswiftc "$frameworks" \
        -Xlinker -F -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib" \
        ${plugin_flags[@]+"${plugin_flags[@]}"} "$@"
else
    swift test "$@"
fi
