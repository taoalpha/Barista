#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
ASSETS_DIR="$PROJECT_ROOT/Barista/Assets.xcassets"
ICONSET_DIR="$ASSETS_DIR/MenubarIcon.imageset"

mkdir -p "$ICONSET_DIR"

# Generate PNGs
# 22pt base size
swift "$DIR/svg2png.swift" "$DIR/menubar.svg" "$ICONSET_DIR/menubar.png" 22
swift "$DIR/svg2png.swift" "$DIR/menubar.svg" "$ICONSET_DIR/menubar@2x.png" 44
swift "$DIR/svg2png.swift" "$DIR/menubar.svg" "$ICONSET_DIR/menubar@3x.png" 66

# Write Contents.json with template rendering intent
cat > "$ICONSET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "menubar.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "menubar@2x.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "menubar@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
EOF

echo "Menubar icon generated in $ICONSET_DIR"
