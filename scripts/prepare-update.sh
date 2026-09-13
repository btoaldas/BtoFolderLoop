#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Prepare a signed appcast in a NEW output directory. Does not publish, prune or install.
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:?Pass the dist output directory containing the app and ZIP}"
app="$output/BtoFolderLoop.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
architecture=$(uname -m)
archive="BtoFolderLoop-$version-macos-$architecture.zip"
tools="$(pwd)/.build/artifacts/sparkle/Sparkle/bin"
account="io.github.btoaldas.BtoFolderLoop.updates"
public_key=$("$tools/generate_keys" --account "$account" -p)
bundle_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")
if [ "$public_key" != "$bundle_key" ]; then
    printf 'Signing key does not match application public key. Stopped.\n' >&2
    exit 1
fi
stage="$output/signed-update-$(uuidgen)"
mkdir "$stage"
cp "$output/$archive" "$stage/$archive"
feed="$stage/appcast-macos-$architecture.xml"
"$tools/generate_appcast" --account "$account" --maximum-deltas 0 --maximum-versions 0 \
    --versions "$build" --download-url-prefix "https://github.com/btoaldas/BtoFolderLoop/releases/download/v$version/" \
    --link "https://github.com/btoaldas/BtoFolderLoop/releases/tag/v$version" -o "$feed" "$stage"
"$tools/sign_update" --account "$account" --verify "$feed"
printf 'FEED=%s\n' "$feed"
