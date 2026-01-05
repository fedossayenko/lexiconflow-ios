#!/usr/bin/env python3
"""
validate_app_store_assets.py

Validate App Store assets meet Apple's requirements.

Usage:
    python3 validate_app_store_assets.py --all
    python3 validate_app_store_assets.py --icon path/to/icon.png
    python3 validate_app_store_assets.py --screenshots path/to/screenshots/
    python3 validate_app_store_assets.py --video path/to/video.m4v
"""

import argparse
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("❌ Error: Pillow is required.")
    print("Install with: pip3 install Pillow")
    sys.exit(1)


# App Store specifications
ICON_SPECS = {
    "size": (1024, 1024),
    "format": "PNG",
    "max_size_mb": 0.5,
    "no_alpha": True,
}

SCREENSHOT_SPECS = {
    "iphone_se": {"size": (750, 1334), "count": 6},
    "iphone_15": {"size": (1179, 2556), "count": 6},
    "iphone_15_pro_max": {"size": (1290, 2796), "count": 6},
    "ipad": {"size": (1640, 2360), "count": 6},
}

VIDEO_SPECS = {
    "duration_min": 27,
    "duration_max": 30,
    "resolution": (1920, 1080),
    "format": ["M4V", "MOV"],
    "max_size_mb": 50,
    "codec": "H.264",
}


def validate_icon(icon_path):
    """Validate app icon meets App Store requirements."""
    print(f"\n🔍 Validating app icon: {icon_path}")

    if not os.path.exists(icon_path):
        print(f"  ❌ File not found")
        return False

    try:
        img = Image.open(icon_path)
        width, height = img.size
        format = img.format
        mode = img.mode
        file_size_mb = os.path.getsize(icon_path) / (1024 * 1024)

        errors = []
        warnings = []

        # Check dimensions
        if width != ICON_SPECS["size"][0] or height != ICON_SPECS["size"][1]:
            errors.append(f"Wrong size: {width}×{height}, expected {ICON_SPECS['size'][0]}×{ICON_SPECS['size'][1]}")

        # Check format
        if format != ICON_SPECS["format"]:
            errors.append(f"Wrong format: {format}, expected {ICON_SPECS['format']}")

        # Check file size
        if file_size_mb > ICON_SPECS["max_size_mb"]:
            errors.append(f"File too large: {file_size_mb:.2f}MB, max {ICON_SPECS['max_size_mb']}MB")

        # Check for alpha channel
        if mode == "RGBA" and ICON_SPECS["no_alpha"]:
            warnings.append("Image has alpha channel (transparency). App Store prefers solid background.")

        # Print results
        if errors:
            for error in errors:
                print(f"  ❌ {error}")
            return False
        elif warnings:
            for warning in warnings:
                print(f"  ⚠️  {warning}")
            print(f"  ✅ Icon passes validation (with warnings)")
            return True
        else:
            print(f"  ✅ Icon passes all validation checks")
            print(f"     - Size: {width}×{height}")
            print(f"     - Format: {format}")
            print(f"     - File size: {file_size_mb:.2f}MB")
            return True

    except Exception as e:
        print(f"  ❌ Error reading image: {e}")
        return False


def validate_screenshots(screenshots_dir):
    """Validate screenshots meet App Store requirements."""
    print(f"\n🔍 Validating screenshots: {screenshots_dir}")

    if not os.path.isdir(screenshots_dir):
        print(f"  ❌ Directory not found")
        return False

    all_passed = True

    for device, specs in SCREENSHOT_SPECS.items():
        print(f"\n  📱 {device.replace('_', ' ').title()}")
        device_dir = os.path.join(screenshots_dir, device)

        if not os.path.isdir(device_dir):
            print(f"    ❌ Directory not found: {device_dir}")
            all_passed = False
            continue

        # Count PNG files
        screenshots = [f for f in os.listdir(device_dir) if f.endswith(".png")]
        actual_count = len(screenshots)

        if actual_count < specs["count"]:
            print(f"    ❌ Found {actual_count} screenshots, expected {specs['count']}")
            all_passed = False
            continue

        # Validate each screenshot
        for screenshot in screenshots:
            screenshot_path = os.path.join(device_dir, screenshot)

            try:
                img = Image.open(screenshot_path)
                width, height = img.size

                expected_width, expected_height = specs["size"]

                if width != expected_width or height != expected_height:
                    print(f"    ❌ {screenshot}: Wrong size {width}×{height}, expected {expected_width}×{expected_height}")
                    all_passed = False
                else:
                    print(f"    ✅ {screenshot}: {width}×{height}")

            except Exception as e:
                print(f"    ❌ {screenshot}: Error - {e}")
                all_passed = False

    if all_passed:
        print(f"\n  ✅ All screenshots validated successfully")

    return all_passed


def validate_video(video_path):
    """Validate preview video meets App Store requirements."""
    print(f"\n🔍 Validating preview video: {video_path}")

    if not os.path.exists(video_path):
        print(f"  ❌ File not found")
        return False

    try:
        # Check file size
        file_size_mb = os.path.getsize(video_path) / (1024 * 1024)

        if file_size_mb > VIDEO_SPECS["max_size_mb"]:
            print(f"  ❌ File too large: {file_size_mb:.2f}MB, max {VIDEO_SPECS['max_size_mb']}MB")
            return False

        # Check format (by extension)
        ext = os.path.splitext(video_path)[1].upper().lstrip(".")
        if ext not in VIDEO_SPECS["format"]:
            print(f"  ⚠️  Extension is {ext}, expected {VIDEO_SPECS['format']}")
            print(f"      (Video may still be valid if container format is correct)")

        # Note: Full validation (duration, resolution, codec) requires ffmpeg
        print(f"  ℹ️  Full video validation requires ffmpeg")
        print(f"  ✅ Basic checks passed:")
        print(f"     - File size: {file_size_mb:.2f}MB (max {VIDEO_SPECS['max_size_mb']}MB)")
        print(f"     - Extension: {ext}")

        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def validate_all():
    """Validate all App Store assets."""
    print("🔍 Validating all App Store assets...")

    results = {}

    # Validate icon
    icon_path = "LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/app-icon.png"
    results["icon"] = validate_icon(icon_path) if os.path.exists(icon_path) else False

    # Validate screenshots
    screenshots_dir = "fastlane/screenshots"
    results["screenshots"] = validate_screenshots(screenshots_dir) if os.path.exists(screenshots_dir) else False

    # Validate video
    video_path = "fastlane/video/exports/lexicon_flow_preview_1080p.m4v"
    results["video"] = validate_video(video_path) if os.path.exists(video_path) else False

    # Print summary
    print("\n" + "="*60)
    print("VALIDATION SUMMARY")
    print("="*60)

    for asset, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{asset.capitalize():15} {status}")

    all_passed = all(results.values())

    print("="*60)
    if all_passed:
        print("✅ ALL ASSETS VALIDATED SUCCESSFULLY")
        return 0
    else:
        print("❌ SOME ASSETS FAILED VALIDATION")
        return 1


def main():
    parser = argparse.ArgumentParser(
        description="Validate App Store assets",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Validate all assets
    python3 validate_app_store_assets.py --all

    # Validate icon only
    python3 validate_app_store_assets.py --icon app-icon.png

    # Validate screenshots only
    python3 validate_app_store_assets.py --screenshots fastlane/screenshots/

    # Validate video only
    python3 validate_app_store_assets.py --video preview.m4v
        """
    )

    parser.add_argument("--all", action="store_true", help="Validate all assets")
    parser.add_argument("--icon", help="Path to app icon PNG")
    parser.add_argument("--screenshots", help="Path to screenshots directory")
    parser.add_argument("--video", help="Path to preview video M4V/MOV")

    args = parser.parse_args()

    if args.all:
        return validate_all()
    elif args.icon:
        return 0 if validate_icon(args.icon) else 1
    elif args.screenshots:
        return 0 if validate_screenshots(args.screenshots) else 1
    elif args.video:
        return 0 if validate_video(args.video) else 1
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
