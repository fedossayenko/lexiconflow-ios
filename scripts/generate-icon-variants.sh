#!/bin/bash
# generate-icon-variants.sh
#
# Generate all iOS icon size variants from a 1024×1024 master app icon.
# Uses ImageMagick for image processing.
#
# Usage:
#   ./generate-icon-variants.sh app-icon.png AppIcon.appiconset/
#
# Requirements:
#   - ImageMagick (install with: brew install imagemagick)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check requirements
check_requirements() {
    if ! command_exists convert; then
        print_error "ImageMagick is not installed"
        echo "Install with: brew install imagemagick"
        exit 1
    fi

    if ! command_exists file; then
        print_error "file command not found"
        exit 1
    fi
}

# Function to validate input image
validate_input() {
    local input="$1"

    if [ ! -f "$input" ]; then
        print_error "Input file not found: $input"
        exit 1
    fi

    # Check if it's a PNG
    if ! file "$input" | grep -q "PNG"; then
        print_error "Input file is not a PNG: $input"
        exit 1
    fi

    # Check dimensions
    local dimensions=$(file "$input" | grep -o '[0-9]* x [0-9]*' | head -1)
    if [ "$dimensions" != "1024 x 1024" ]; then
        print_warning "Input size is $dimensions, expected 1024 x 1024"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    print_success "Input file validated: $input"
}

# Function to generate icon variants
generate_variants() {
    local input="$1"
    local output_dir="$2"
    local suffix="${3:-}"

    echo ""
    echo "📱 Generating iOS icon variants..."
    echo "   Input: $input"
    echo "   Output: $output_dir"
    echo "   Suffix: $suffix"
    echo ""

    # Create output directory
    mkdir -p "$output_dir"

    # Define icon sizes (export_size, filename)
    # Format: "export_size:filename"
    local sizes=(
        "1024:app-icon-1024.png"
        "512:app-icon-512.png"
        "256:app-icon-256.png"
        "128:app-icon-128.png"
        "128:app-icon-64@2x.png"
        "120:app-icon-60@2x.png"
        "180:app-icon-60@3x.png"
        "80:app-icon-40@2x.png"
        "120:app-icon-40@3x.png"
        "58:app-icon-29@2x.png"
        "87:app-icon-29@3x.png"
        "40:app-icon-20@2x.png"
        "60:app-icon-20@3x.png"
        "16:app-icon-16.png"
    )

    local count=0
    local total=${#sizes[@]}

    # Generate each variant
    for size_spec in "${sizes[@]}"; do
        IFS=':' read -r size filename <<< "$size_spec"

        # Add suffix if provided
        if [ -n "$suffix" ]; then
            filename="${filename%.png}${suffix}.png"
        fi

        local output_path="$output_dir/$filename"

        # Resize using high-quality resampling
        convert "$input" \
            -resize "${size}x${size}" \
            -filter Lanczos \
            -quality 95 \
            "$output_path"

        count=$((count + 1))
        print_success "Generated $filename (${size}×${size}) [$count/$total]"
    done

    echo ""
    print_success "Generated $count icon variants in $output_dir"
}

# Function to validate generated icons
validate_icons() {
    local output_dir="$1"

    echo ""
    echo "🔍 Validating generated icons..."

    local all_valid=true
    local expected_files=(
        "app-icon-1024.png"
        "app-icon-512.png"
        "app-icon-256.png"
        "app-icon-128.png"
        "app-icon-64@2x.png"
        "app-icon-60@2x.png"
        "app-icon-60@3x.png"
        "app-icon-40@2x.png"
        "app-icon-40@3x.png"
        "app-icon-29@2x.png"
        "app-icon-29@3x.png"
        "app-icon-20@2x.png"
        "app-icon-20@3x.png"
        "app-icon-16.png"
    )

    for filename in "${expected_files[@]}"; do
        local filepath="$output_dir/$filename"

        if [ ! -f "$filepath" ]; then
            print_error "Missing: $filename"
            all_valid=false
            continue
        fi

        # Check it's a valid PNG
        if ! file "$filepath" | grep -q "PNG"; then
            print_error "$filename: Not a valid PNG"
            all_valid=false
        else
            # Get dimensions
            local dimensions=$(file "$filepath" | grep -o '[0-9]* x [0-9]*' | head -1)
            local filesize=$(ls -lh "$filepath" | awk '{print $5}')
            print_success "$filename: $dimensions, $filesize"
        fi
    done

    if [ "$all_valid" = true ]; then
        print_success "All icons validated successfully"
        return 0
    else
        print_error "Some icons failed validation"
        return 1
    fi
}

# Function to optimize PNGs
optimize_pngs() {
    local output_dir="$1"

    echo ""
    echo "⚡️  Optimizing PNG files..."

    if command_exists optipng; then
        find "$output_dir" -name "*.png" -exec optipng -o7 -quiet {} \;
        print_success "Optimized with optipng"
    elif command_exists pngcrush; then
        find "$output_dir" -name "*.png" -exec pngcrush -brute -q {} {} \; \
            && find "$output_dir" -name "*.png.*" -delete
        print_success "Optimized with pngcrush"
    else
        print_warning "No PNG optimizer found (install optipng or pngcrush)"
        return 1
    fi
}

# Main function
main() {
    # Parse arguments
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <input.png> [output_dir] [suffix]"
        echo ""
        echo "Examples:"
        echo "  $0 app-icon.png AppIcon.appiconset/"
        echo "  $0 app-icon.png AppIcon.appiconset/ -dark"
        exit 1
    fi

    local input="$1"
    local output_dir="${2:-LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/}"
    local suffix="${3:-}"

    # Check requirements
    check_requirements

    # Validate input
    validate_input "$input"

    # Generate variants
    generate_variants "$input" "$output_dir" "$suffix"

    # Validate generated icons
    validate_icons "$output_dir"

    # Optimize PNGs (optional)
    if command_exists optipng || command_exists pngcrush; then
        read -p "Optimize PNG files? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            optimize_pngs "$output_dir"
        fi
    fi

    echo ""
    echo "🎉 Icon generation complete!"
    echo "📂 Icons saved to: $output_dir"
    echo ""
    echo "Next steps:"
    echo "  1. Review generated icons visually"
    echo "  2. Test in iOS Simulator"
    echo "  3. Commit to git"
}

# Run main function
main "$@"
