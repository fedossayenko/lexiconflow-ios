#!/usr/bin/env python3
"""
generate-icon-variants.py

Generate all iOS icon size variants from a 1024×1024 master app icon.

Usage:
    python3 generate-icon-variants.py --input app-icon.png --output AppIcon.appiconset/

Requirements:
    - Python 3.6+
    - Pillow (pip install Pillow)
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple

try:
    from PIL import Image
except ImportError:
    print("❌ Error: Pillow is required.")
    print("Install with: pip3 install Pillow")
    sys.exit(1)


# iOS icon size specifications
IOS_ICON_SIZES = [
    # (export_size, display_size, scale, filename)
    (1024, 1024, 1, "app-icon-1024.png"),
    (512, 512, 1, "app-icon-512.png"),
    (256, 256, 1, "app-icon-256.png"),
    (128, 128, 1, "app-icon-128.png"),
    (128, 64, 2, "app-icon-64@2x.png"),
    (120, 60, 2, "app-icon-60@2x.png"),
    (180, 60, 3, "app-icon-60@3x.png"),
    (80, 40, 2, "app-icon-40@2x.png"),
    (120, 40, 3, "app-icon-40@3x.png"),
    (58, 29, 2, "app-icon-29@2x.png"),
    (87, 29, 3, "app-icon-29@3x.png"),
    (40, 20, 2, "app-icon-20@2x.png"),
    (60, 20, 3, "app-icon-20@3x.png"),
    (16, 16, 1, "app-icon-16.png"),
]


def generate_variants(
    input_path: str,
    output_dir: str,
    suffix: str = "",
    quality: int = 95,
) -> List[str]:
    """
    Generate all iOS icon variants from a master image.

    Args:
        input_path: Path to 1024×1024 master PNG
        output_dir: Directory to save variants
        suffix: Optional suffix to add to filenames (e.g., "-dark")
        quality: PNG quality (1-100, default 95)

    Returns:
        List of generated file paths
    """
    # Validate input
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    # Load master image
    print(f"📱 Loading master icon: {input_path}")
    try:
        master = Image.open(input_path)
        master_width, master_height = master.size

        if master_width != 1024 or master_height != 1024:
            print(f"⚠️  Warning: Master size is {master_width}×{master_height}, expected 1024×1024")
            response = input("Continue anyway? (y/n): ")
            if response.lower() != 'y':
                sys.exit(1)

    except Exception as e:
        print(f"❌ Error loading image: {e}")
        sys.exit(1)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Generate each variant
    generated_files = []
    for export_size, display_size, scale, filename in IOS_ICON_SIZES:
        # Add suffix if provided
        if suffix:
            name, ext = os.path.splitext(filename)
            filename = f"{name}{suffix}{ext}"

        output_path = os.path.join(output_dir, filename)

        # Resize using high-quality Lanczos resampling
        resized = master.resize(
            (export_size, export_size),
            Image.Resampling.LANCZOS
        )

        # Save as PNG
        resized.save(output_path, "PNG", quality=quality)
        generated_files.append(output_path)

        print(f"  ✓ Generated {filename} ({export_size}×{export_size}, {display_size}@{scale}x)")

    print(f"\n✅ Generated {len(generated_files)} icon variants in {output_dir}")
    return generated_files


def generate_contents_json(
    output_dir: str,
    suffixes: List[str] = ["", "-dark"],
) -> str:
    """
    Generate Contents.json for Xcode asset catalog.

    Args:
        output_dir: Directory containing icon PNGs
        suffixes: List of filename suffixes (e.g., ["", "-dark"])

    Returns:
        Path to generated Contents.json
    """
    images = []

    # Build image entries for each suffix (light/dark mode)
    for suffix in suffixes:
        appearance = {"appearances": [{"appearance": "luminosity", "value": "dark"}]} if suffix == "-dark" else {}

        for export_size, display_size, scale, filename in IOS_ICON_SIZES:
            # Add suffix to filename
            if suffix:
                name, ext = os.path.splitext(filename)
                filename = f"{name}{suffix}{ext}"

            # Check if file exists
            filepath = os.path.join(output_dir, filename)
            if not os.path.exists(filepath):
                continue

            # Build image entry
            if export_size == 1024:
                # App Store universal icon
                entry = {
                    "filename": filename,
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                }
            elif display_size in [60, 40, 29, 20]:
                # iOS device icons
                entry = {
                    "filename": filename,
                    "idiom": "iphone" if export_size in [120, 180, 58, 87, 40, 60] else "ipad",
                    "scale": f"{scale}x",
                    "size": f"{display_size}x{display_size}",
                }
            elif display_size in [16, 32, 64, 128, 256, 512]:
                # macOS icons
                entry = {
                    "filename": filename,
                    "idiom": "mac",
                    "scale": f"{scale}x" if scale > 1 else "1x",
                    "size": f"{display_size}x{display_size}",
                }

            # Add dark mode appearance if suffix is "-dark"
            if suffix == "-dark":
                entry.update(appearance)

            images.append(entry)

    # Build Contents.json structure
    contents = {
        "images": images,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    # Write Contents.json
    output_path = os.path.join(output_dir, "Contents.json")
    with open(output_path, "w") as f:
        json.dump(contents, f, indent=2)

    print(f"📝 Generated Contents.json with {len(images)} entries")
    return output_path


def validate_icons(output_dir: str) -> bool:
    """
    Validate generated icons meet App Store requirements.

    Args:
        output_dir: Directory containing icon PNGs

    Returns:
        True if all validations pass
    """
    print("\n🔍 Validating generated icons...")

    all_valid = True
    required_files = [f[3] for f in IOS_ICON_SIZES]

    for filename in required_files:
        filepath = os.path.join(output_dir, filename)

        if not os.path.exists(filepath):
            print(f"  ❌ Missing: {filename}")
            all_valid = False
            continue

        # Check file is valid PNG
        try:
            img = Image.open(filepath)
            width, height = img.size

            # Verify dimensions match expected
            expected_size = next(f[0] for f in IOS_ICON_SIZES if f[3] == filename)
            if width != expected_size or height != expected_size:
                print(f"  ❌ {filename}: Wrong size ({width}×{height}, expected {expected_size}×{expected_size})")
                all_valid = False
            else:
                print(f"  ✓ {filename}: {width}×{height}, {os.path.getsize(filepath) / 1024:.1f} KB")

        except Exception as e:
            print(f"  ❌ {filename}: Invalid PNG - {e}")
            all_valid = False

    if all_valid:
        print("✅ All icons validated successfully")
    else:
        print("❌ Some icons failed validation")

    return all_valid


def main():
    parser = argparse.ArgumentParser(
        description="Generate iOS icon variants from 1024×1024 master",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Generate light mode icons
    python3 generate-icon-variants.py --input app-icon.png --output AppIcon.appiconset/

    # Generate dark mode icons
    python3 generate-icon-variants.py --input app-icon-dark.png --output AppIcon.appiconset/ --suffix -dark

    # Generate both light and dark mode, then update Contents.json
    python3 generate-icon-variants.py --input app-icon.png --output AppIcon.appiconset/
    python3 generate-icon-variants.py --input app-icon-dark.png --output AppIcon.appiconset/ --suffix -dark
    python3 generate-icon-variants.py --output AppIcon.appiconset/ --update-contents-json
        """
    )

    parser.add_argument(
        "--input", "-i",
        help="Path to 1024×1024 master PNG file",
    )
    parser.add_argument(
        "--output", "-o",
        default="LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/",
        help="Output directory for generated icons (default: AppIcon.appiconset/)",
    )
    parser.add_argument(
        "--suffix", "-s",
        default="",
        help="Suffix to add to filenames (e.g., '-dark' for dark mode variants)",
    )
    parser.add_argument(
        "--quality", "-q",
        type=int,
        default=95,
        help="PNG quality 1-100 (default: 95)",
    )
    parser.add_argument(
        "--update-contents-json",
        action="store_true",
        help="Generate Contents.json for Xcode asset catalog (use after generating all variants)",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate generated icons after creation",
    )

    args = parser.parse_args()

    # Update Contents.json mode
    if args.update_contents_json:
        if not os.path.isdir(args.output):
            print(f"❌ Error: Output directory not found: {args.output}")
            sys.exit(1)

        generate_contents_json(args.output)
        print("\n🚀 Ready to import into Xcode!")
        return

    # Generate variants mode
    if not args.input:
        parser.print_help()
        print("\n❌ Error: --input is required (unless using --update-contents-json)")
        sys.exit(1)

    try:
        # Generate variants
        generate_variants(
            input_path=args.input,
            output_dir=args.output,
            suffix=args.suffix,
            quality=args.quality,
        )

        # Validate if requested
        if args.validate:
            validate_icons(args.output)

        print("\n🎉 Icon generation complete!")
        print(f"📂 Icons saved to: {args.output}")
        print("\nNext steps:")
        print("  1. Review generated icons visually")
        print("  2. Test in iOS Simulator")
        print("  3. Commit to git")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
