#!/usr/bin/env bash
# Check the actual UIKit importer against both SDKs, without renderer downloads.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for sdk in iphoneos iphonesimulator; do
    target=arm64-apple-ios27.0
    [[ "$sdk" != iphonesimulator ]] || target="$target-simulator"
    xcrun --sdk "$sdk" clang++ -target "$target" \
        -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
        -fobjc-arc -fsyntax-only -Wall -Wextra -Werror -Wno-deprecated-declarations \
        '-DCOS_GAME_ID_STR="GZLE01"' "$repo/ios/src/platform.mm"
    echo "UIKit importer: $sdk OK"
done
plutil -lint "$repo/ios/Info.plist.in"
