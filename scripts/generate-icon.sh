#!/bin/bash
#
# Regenerate Resources/AppIcon.icns from Resources/AppIcon.svg.
#
# Uses only macOS built-ins (qlmanage, sips, iconutil), so no external
# tools or Homebrew packages are required.
#
# Run this when you change the SVG. The produced .icns is committed; build.sh
# only copies it into the .app bundle.

set -euo pipefail

cd "$(dirname "$0")/.."

SVG="Resources/AppIcon.svg"
ICNS="Resources/AppIcon.icns"
WORKDIR="$(mktemp -d)"
SOURCE_PNG="$WORKDIR/source.png"
ICONSET="$WORKDIR/AppIcon.iconset"

trap "rm -rf '$WORKDIR'" EXIT

echo "Rasterizing $SVG -> 1024x1024 PNG"
qlmanage -t -s 1024 -o "$WORKDIR" "$SVG" >/dev/null 2>&1
mv "$WORKDIR/AppIcon.svg.png" "$SOURCE_PNG"

mkdir -p "$ICONSET"

for spec in \
    "16:icon_16x16.png" \
    "32:icon_16x16@2x.png" \
    "32:icon_32x32.png" \
    "64:icon_32x32@2x.png" \
    "128:icon_128x128.png" \
    "256:icon_128x128@2x.png" \
    "256:icon_256x256.png" \
    "512:icon_256x256@2x.png" \
    "512:icon_512x512.png" \
    "1024:icon_512x512@2x.png"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Generated $ICNS"
