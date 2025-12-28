#!/bin/bash
set -e

# Determine project root (assuming script is in scripts/ folder)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Move to project root to keep paths consistent
cd "$PROJECT_ROOT"

# Base paths
SVG_ORIG="$SCRIPT_DIR/barista.svg"
SOURCE_PNG="$SCRIPT_DIR/barista.png"
ASSETS_DIR="$PROJECT_ROOT/Barista/Assets.xcassets/AppIcon.appiconset"

# Verify execution context
if [ ! -f "$SVG_ORIG" ]; then
    echo "Error: file $SVG_ORIG not found. Ensure the script is running from the project root or scripts/ folder."
    exit 1
fi

echo "Generating master icon from native 1024x1024 SVG..."

# Rasterize to PNG using custom Swift script
# No temporary scaling needed as SVG is now 1024x1024
swift "$SCRIPT_DIR/svg2png.swift" "$SVG_ORIG" "$SOURCE_PNG" 1024

if [ ! -f "$SOURCE_PNG" ]; then
    echo "Error: Failed to generate master PNG at $SOURCE_PNG"
    exit 1
fi

echo "Master PNG generated. Resizing to assets..."

# Generate all sizes using sips
generate_icon() {
    local name=$1
    local size=$2
    sips -z $size $size "$SOURCE_PNG" --out "$ASSETS_DIR/$name" > /dev/null
    echo "Generated $name ($size x $size)"
}

generate_icon "icon_16x16.png" 16
generate_icon "icon_16x16@2x.png" 32
generate_icon "icon_32x32.png" 32
generate_icon "icon_32x32@2x.png" 64
generate_icon "icon_128x128.png" 128
generate_icon "icon_128x128@2x.png" 256
generate_icon "icon_256x256.png" 256
generate_icon "icon_256x256@2x.png" 512
generate_icon "icon_512x512.png" 512
generate_icon "icon_512x512@2x.png" 1024

# Cleanup
rm "$SOURCE_PNG"
echo "Done. Cleanup complete."
