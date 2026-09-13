#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product BtoFolderLoop -Xswiftc -gnone
bin_dir="$(swift build -c release --show-bin-path)"
build_id="$(date +%Y%m%d-%H%M%S)-$$"
output="$(pwd)/dist/$build_id"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
app="$output/BtoFolderLoop.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin_dir/BtoFolderLoop" "$app/Contents/MacOS/BtoFolderLoop"
strip -S "$app/Contents/MacOS/BtoFolderLoop"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL https://raw.githubusercontent.com/btoaldas/BtoFolderLoop/main/updates/appcast-macos-$(uname -m).xml" "$app/Contents/Info.plist"
sparkle="$(pwd)/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$sparkle" "$app/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$app/Contents/Resources/Sparkle-LICENSE.txt"
for bundle in "$bin_dir"/*.bundle; do
  [ -d "$bundle" ] || continue
  cp -R "$bundle" "$app/Contents/Resources/"
done
cp LICENSE "$app/Contents/Resources/LICENSE"
bash scripts/build-icon.sh Sources/BtoFolderLoopApp/Resources/BrandIcon.png "$output"
cp "$output/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
archive="$output/BtoFolderLoop-$version-macos-$(uname -m).zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(cd "$output" && shasum -a 256 "$(basename "$archive")" > SHA256SUMS)
printf 'version=%s\narchitecture=%s\nminimum_macos=14\nsigning=ad-hoc\nnotarized=false\nsource_commit=%s\n' \
  "$version" "$(uname -m)" "$(git rev-parse HEAD)" > "$output/BUILD-INFO.txt"
printf '%s\n' "$app" > dist/latest-app.txt
printf '%s\n' "$output" > dist/latest-output.txt
printf 'APP=%s\nARCHIVE=%s\n' "$app" "$archive"
