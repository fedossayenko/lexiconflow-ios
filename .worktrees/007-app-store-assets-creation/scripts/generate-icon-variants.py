#!/usr/bin/env python3
"""
Generate iOS App Icon Variants from Master Icon

Generates all required iOS app icon sizes from a 1024x1024 master icon.
Supports custom sizes and automatic quality optimization.

Usage:
    python3 generate-icon-variants.py <master_icon> [output_dir]

Examples:
    python3 generate-icon-variants.py AppIcon-1024.png
    python3 generate-icon-variants.py AppIcon-1024.png ./icon-variants

Requirements:
    - Python 3.6+
    - Pillow (PIL): pip install Pillow
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow (PIL) is required.")
    print("Install with: pip install Pillow")
    sys.exit(1)


# iOS app icon sizes (all required sizes)
ICON_SIZES = [
    16,    # Notification Center, Document Outline (macOS)
    29,    # Settings (iOS)
    32,    # Finder (macOS)
    40,    # iPhone Spotlight (iOS)
    58,    # Settings @2x (iOS)
    60,    # iPhone App @2x (iOS)
    76,    # iPad App (iOS)
    80,    # iPhone Spotlight @2x (iOS)
    87,    # iPhone Notification @3x (iOS)
    120,   # iPhone App @2x (iOS)
    152,   # iPad App @2x (iOS)
    167,   # iPad Pro App @2x (iOS)
    180,   # iPhone App @3x (iOS)
    1024,  # App Store (master)
]


def generate_icon_variants(master_path, output_dir="icon-variants"):
    """
    Generate all iOS icon sizes from master icon.

    Args:
        master_path: Path to 1024x1024 master icon
        output_dir: Directory for generated icons (default: icon-variants)
    """
    # Validate input
    master_path = Path(master_path)
    if not master_path.exists():
        print(f"Error: Master icon not found: {master_path}")
        sys.exit(1)

    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Open master icon
    print(f"Opening master icon: {master_path}")
    try:
        with Image.open(master_path) as master:
            # Verify master size
            if master.size != (1024, 1024):
                print(f"Warning: Master icon is {master.size[0]}x{master.size[1]}, not 1024x1024")
                response = input("Continue anyway? (y/n): ")
                if response.lower() != 'y':
                    sys.exit(1)

            # Convert to RGB if necessary (removes alpha channel if present)
            if master.mode in ('RGBA', 'LA', 'P'):
                # Create white background for transparent images
                background = Image.new('RGB', master.size, (255, 255, 255))
                if master.mode == 'P':
                    master = master.convert('RGBA')
                background.paste(master, mask=master.split()[-1] if master.mode == 'RGBA' else None)
                master = background
            elif master.mode != 'RGB':
                master = master.convert('RGB')

            # Generate each size
            generated_count = 0
            for size in ICON_SIZES:
                if size == 1024:
                    # Copy master directly
                    output_file = output_path / f"AppIcon-1024x1024.png"
                    master.save(output_file, "PNG", optimize=True)
                else:
                    # Resize using high-quality resampling
                    resized = master.resize((size, size), Image.Resampling.LANCZOS)
                    output_file = output_path / f"AppIcon-{size}x{size}.png"
                    resized.save(output_file, "PNG", optimize=True)

                generated_count += 1
                file_size = output_file.stat().st_size / 1024  # KB
                print(f"  Generated: {output_file.name} ({size}x{size}) - {file_size:.1f} KB")

    except Exception as e:
        print(f"Error processing master icon: {e}")
        sys.exit(1)

    print(f"\n✅ Generated {generated_count} icon variants in: {output_path}")
    print(f"\nNext steps:")
    print(f"  1. Review generated icons")
    print(f"  2. Add to Xcode: Assets.xcassets/AppIcon/")
    print(f"  3. Or use fastlane to upload to App Store Connect")


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: python3 generate-icon-variants.py <master_icon> [output_dir]")
        print("\nExamples:")
        print("  python3 generate-icon-variants.py AppIcon-1024.png")
        print("  python3 generate-icon-variants.py AppIcon-1024.png ./icon-variants")
        sys.exit(1)

    master_icon = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "icon-variants"

    generate_icon_variants(master_icon, output_dir)


if __name__ == "__main__":
    main()
