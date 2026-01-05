#!/usr/bin/env python3
"""
process_screenshots.py

Process raw screenshots for App Store submission.
Adds captions, device frames, and optimization.

Usage:
    python3 process_screenshots.py --device iphone_15 --input raw/ --output processed/
"""

import argparse
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("❌ Error: Pillow is required.")
    print("Install with: pip3 install Pillow")
    sys.exit(1)


# Device specifications
DEVICE_SPECS = {
    "iphone_se": {
        "name": "iPhone SE",
        "screen_size": (375, 667),
        "export_size": (750, 1334),
        "scale": 2,
    },
    "iphone_15": {
        "name": "iPhone 15",
        "screen_size": (393, 852),
        "export_size": (1179, 2556),
        "scale": 3,
    },
    "iphone_15_pro_max": {
        "name": "iPhone 15 Pro Max",
        "screen_size": (430, 932),
        "export_size": (1290, 2796),
        "scale": 3,
    },
    "ipad": {
        "name": "iPad (10th Gen)",
        "screen_size": (820, 1180),
        "export_size": (1640, 2360),
        "scale": 2,
    },
}

# Captions for each screenshot
CAPTIONS = {
    1: "Tired of forgetting what you learn?",
    2: "90% retention with FSRS v5 algorithm",
    3: "Beautiful Liquid Glass interface",
    4: "Flashcards, Quiz, and Writing modes",
    5: "Smart scheduling optimizes study time",
    6: "Start learning vocabulary today",
}


def add_caption(img, text, device_name):
    """
    Add caption overlay to screenshot.

    Args:
        img: PIL Image
        text: Caption text
        device_name: Device name for font sizing

    Returns:
        PIL Image with caption
    """
    width, height = img.size

    # Create overlay
    overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Caption positioning
    caption_height = int(height * 0.25)
    caption_y = height - caption_height

    # Semi-transparent background
    draw.rectangle(
        [(0, caption_y), (width, height)],
        fill=(0, 0, 0, 153)  # Black with 60% opacity
    )

    # Font size based on device
    if "iPad" in device_name:
        font_size = 56
    else:
        font_size = 40

    # Load font
    try:
        # Try system font first
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        # Fall back to default
        font = ImageFont.load_default()

    # Calculate text position (centered)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_x = (width - text_width) // 2
    text_y = caption_y + int(caption_height * 0.3)

    # Draw text
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)

    # Composite caption onto image
    result = Image.alpha_composite(img.convert('RGBA'), overlay)

    return result.convert('RGB')


def process_screenshot(
    input_path,
    output_path,
    caption_text=None,
    device_name="iPhone"
):
    """
    Process a single screenshot.

    Args:
        input_path: Path to raw screenshot
        output_path: Path to save processed screenshot
        caption_text: Optional caption text
        device_name: Device name for font sizing
    """
    # Load image
    img = Image.open(input_path)

    # Add caption if provided
    if caption_text:
        img = add_caption(img, caption_text, device_name)

    # Save
    img.save(output_path, 'PNG', optimize=True)
    print(f"  ✓ Processed: {os.path.basename(output_path)}")


def batch_process(
    input_dir,
    output_dir,
    device_type,
    add_captions=True,
    add_frames=False
):
    """
    Process all screenshots in a directory.

    Args:
        input_dir: Directory containing raw screenshots
        output_dir: Directory to save processed screenshots
        device_type: Device type (iphone_se, iphone_15, etc.)
        add_captions: Whether to add caption overlays
        add_frames: Whether to add device frames (not implemented)
    """
    # Get device specs
    if device_type not in DEVICE_SPECS:
        print(f"❌ Error: Unknown device type: {device_type}")
        print(f"Valid types: {', '.join(DEVICE_SPECS.keys())}")
        sys.exit(1)

    specs = DEVICE_SPECS[device_type]
    device_name = specs["name"]
    export_size = specs["export_size"]

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Process each screenshot (1-6)
    for i in range(1, 7):
        # Input filename pattern
        input_files = [
            f"{i}.png",
            f"{i}_raw.png",
            f"screenshot_{i}.png",
        ]

        input_path = None
        for filename in input_files:
            test_path = os.path.join(input_dir, filename)
            if os.path.exists(test_path):
                input_path = test_path
                break

        if not input_path:
            print(f"⚠️  Warning: Screenshot {i} not found in {input_dir}")
            continue

        # Output filename
        title = {
            1: "FORGET_LESS",
            2: "FSRS_V5",
            3: "LIQUID_GLASS",
            4: "STUDY_MODES",
            5: "SMART_SCHEDULING",
            6: "START_LEARNING",
        }[i]

        width, height = export_size
        output_filename = f"{i}_{title}_{width}x{height}.png"
        output_path = os.path.join(output_dir, output_filename)

        # Caption text
        caption_text = CAPTIONS[i] if add_captions else None

        # Process
        process_screenshot(
            input_path,
            output_path,
            caption_text,
            device_name
        )

    print(f"\n✅ Processed screenshots in {output_dir}")


def main():
    parser = argparse.ArgumentParser(
        description="Process App Store screenshots",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Process iPhone 15 screenshots with captions
    python3 process_screenshots.py --device iphone_15 --input raw/ --output processed/

    # Process iPad screenshots without captions
    python3 process_screenshots.py --device ipad --input raw/ --output processed/ --no-captions

Device types:
    iphone_se, iphone_15, iphone_15_pro_max, ipad
        """
    )

    parser.add_argument(
        "--device", "-d",
        required=True,
        choices=list(DEVICE_SPECS.keys()),
        help="Device type"
    )
    parser.add_argument(
        "--input", "-i",
        default="screenshots_raw/",
        help="Input directory containing raw screenshots"
    )
    parser.add_argument(
        "--output", "-o",
        default="fastlane/screenshots/",
        help="Output directory for processed screenshots"
    )
    parser.add_argument(
        "--no-captions",
        action="store_true",
        help="Don't add caption overlays"
    )
    parser.add_argument(
        "--add-frames",
        action="store_true",
        help="Add device frames (not yet implemented)"
    )

    args = parser.parse_args()

    # Build paths
    input_dir = os.path.join(args.input, args.device)
    output_dir = os.path.join(args.output, args.device)

    print(f"📱 Processing {args.device} screenshots...")
    print(f"   Input:  {input_dir}")
    print(f"   Output: {output_dir}")
    print(f"   Captions: {'Yes' if not args.no_captions else 'No'}")
    print()

    # Process
    batch_process(
        input_dir=input_dir,
        output_dir=output_dir,
        device_type=args.device,
        add_captions=not args.no_captions,
        add_frames=args.add_frames
    )

    print("\n🎉 Screenshot processing complete!")


if __name__ == "__main__":
    main()
