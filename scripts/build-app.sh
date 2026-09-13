#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product BtoFolderLoop -Xswiftc -gnone
bin_dir="$(swift build -c release --show-bin-path)"
build_id="$(date +%Y%m%d-%H%M%S)-$$"
output="$(pwd)/dist/$build_id"
app="$output/BtoFolderLoop.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/BtoFolderLoop" "$app/Contents/MacOS/BtoFolderLoop"
strip -S "$app/Contents/MacOS/BtoFolderLoop"
cp Resources/Info.plist "$app/Contents/Info.plist"
for bundle in "$bin_dir"/*.bundle; do
  [ -d "$bundle" ] || continue
  cp -R "$bundle" "$app/Contents/Resources/"
done
cp LICENSE "$app/Contents/Resources/LICENSE"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
archive="$output/BtoFolderLoop-0.1.0-macos-$(uname -m).zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$output/SHA256SUMS"
printf '%s\n' "$app" > dist/latest-app.txt
printf '%s\n' "$output" > dist/latest-output.txt
printf 'APP=%s\nARCHIVE=%s\n' "$app" "$archive"
