#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"
if [[ -d "$TEST_FRAMEWORKS/Testing.framework" ]]; then
    swift test -Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS" "$@"
else
    swift test "$@"
fi
