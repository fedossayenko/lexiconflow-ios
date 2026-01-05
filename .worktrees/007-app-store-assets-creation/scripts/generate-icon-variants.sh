#!/bin/bash
# Generate iOS App Icon Variants using macOS built-in sips command
#
# Usage: ./generate-icon-variants.sh [master_icon] [output_dir]
# Example: ./generate-icon-variants.sh AppIcon-1024.png

set -e  # Exit on error

# Default values
MASTER_ICON="${1:-AppIcon-1024.png}"
OUTPUT_DIR="${2:-icon-variants}"

# iOS app icon sizes (all required sizes)
SIZES=(16 29 32 40 58 60 76 80 87 120 152 167 180 1024)

# Create output directory
echo "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Check if master icon exists
if [ ! -f "$MASTER_ICON" ]; then
    echo "Error: Master icon not found: $MASTER_ICON"
    exit 1
fi

echo "Generating icon variants from: $MASTER_ICON"
echo ""

# Generate each size
GENERATED_COUNT=0
for size in "${SIZES[@]}"; do
    OUTPUT_FILE="$OUTPUT_DIR/AppIcon-${size}x${size}.png"

    if [ "$size" -eq 1024 ]; then
        # Copy master directly
        cp "$MASTER_ICON" "$OUTPUT_FILE"
    else
        # Resize using sips
        sips -z "$size" "$size" "$MASTER_ICON" --out "$OUTPUT_FILE" > /dev/null 2>&1
    fi

    # Get file size
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "  Generated: AppIcon-${size}x${size}.png (${size}x${size}) - $FILE_SIZE"
        ((GENERATED_COUNT++))
    else
        echo "  Error: Failed to generate AppIcon-${size}x${size}.png"
    fi
done

echo ""
echo "✅ Generated $GENERATED_COUNT icon variants in: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Review generated icons"
echo "  2. Add to Xcode: Assets.xcassets/AppIcon/"
echo "  3. Or use fastlane to upload to App Store Connect"
