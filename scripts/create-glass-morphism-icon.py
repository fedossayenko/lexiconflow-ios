#!/usr/bin/env python3
"""
create-glass-morphism-icon.py

Generate a glass morphism app icon for LexiconFlow programmatically.

Creates:
- app-icon.png (1024×1024, light mode)
- app-icon-dark.png (1024×1024, dark mode)

Requirements:
    - Python 3.6+
    - Pillow (pip install Pillow)
    - NumPy (pip install numpy)
"""

import sys
import os

try:
    from PIL import Image, ImageDraw, ImageFilter
    import numpy as np
except ImportError as e:
    print(f"❌ Error: Missing required library: {e}")
    print("Install with: pip3 install Pillow numpy")
    sys.exit(1)


def create_noise_texture(width, height, opacity=5):
    """
    Create a noise texture overlay.

    Args:
        width: Image width
        height: Image height
        opacity: Opacity percentage (1-100)

    Returns:
        PIL Image with noise texture
    """
    # Generate random noise
    noise = np.random.randint(0, 256, (height, width), dtype=np.uint8)

    # Convert to PIL Image
    noise_img = Image.fromarray(noise, mode='L')

    # Create RGBA version with opacity
    noise_rgba = noise_img.convert('RGBA')
    alpha = int(255 * opacity / 100)
    noise_rgba.putalpha(alpha)

    return noise_rgba


def create_gradient_color(size, color_start, color_middle, color_end):
    """
    Create a linear gradient from top-left to bottom-right.

    Args:
        size: Tuple (width, height)
        color_start: RGB tuple for start color
        color_middle: RGB tuple for middle color
        color_end: RGB tuple for end color

    Returns:
        PIL Image with gradient
    """
    width, height = size

    # Create gradient array
    gradient = np.zeros((height, width, 3), dtype=np.uint8)

    for y in range(height):
        for x in range(width):
            # Calculate position along diagonal (0 to 1)
            pos = (x + y) / (width + height)

            # Interpolate between colors
            if pos < 0.5:
                # Start to middle
                t = pos * 2
                r = int(color_start[0] * (1 - t) + color_middle[0] * t)
                g = int(color_start[1] * (1 - t) + color_middle[1] * t)
                b = int(color_start[2] * (1 - t) + color_middle[2] * t)
            else:
                # Middle to end
                t = (pos - 0.5) * 2
                r = int(color_middle[0] * (1 - t) + color_end[0] * t)
                g = int(color_middle[1] * (1 - t) + color_end[1] * t)
                b = int(color_middle[2] * (1 - t) + color_end[2] * t)

            gradient[y, x] = [r, g, b]

    return Image.fromarray(gradient, mode='RGB')


def create_fluid_L(size, gradient_img):
    """
    Create a calligraphic fluid 'L' symbol.

    Args:
        size: Tuple (width, height)
        gradient_img: Gradient image to use as fill

    Returns:
        PIL Image with fluid 'L' symbol (RGBA, transparent background)
    """
    width, height = size
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # L dimensions
    l_height = int(height * 0.5)  # ~500px for 1024px canvas
    l_width = int(l_height * 0.7)  # ~350px
    stroke_thick = 120  # Thickest point
    stroke_thin = 60    # Thinnest point

    # Center position
    center_x = width // 2
    center_y = height // 2
    left = center_x - l_width // 2
    top = center_y - l_height // 2
    right = left + l_width
    bottom = top + l_height

    # Draw calligraphic 'L' using polygon for custom shape
    # Vertical stroke with tapering
    crossbar_y = top + int(l_height * 0.25)  # 25% from top

    # Polygon points for fluid 'L'
    points = [
        # Left side of vertical stroke (tapered at top)
        (left + stroke_thick // 3, top),  # Top-left
        (left + stroke_thick // 2, top + 50),  # Below top

        # Vertical stroke right side
        (left + stroke_thick, top + l_height * 0.1),  # Start of thick section
        (left + stroke_thick, bottom - 20),  # Bottom-right before corner

        # Corner to horizontal stroke
        (left + stroke_thin + 20, bottom),  # Bottom-right of corner
        (left + stroke_thin, bottom),  # Bottom-left of corner

        # Horizontal stroke left side
        (left + stroke_thin, crossbar_y + stroke_thin),  # Left of crossbar

        # Horizontal stroke right side
        (left + l_width * 0.7, crossbar_y + stroke_thin),  # Right of crossbar
        (left + l_width * 0.7, crossbar_y),  # Top of crossbar

        # Return to top
        (left + stroke_thick // 2, top + 50),  # Back to vertical
        (left + stroke_thick // 3, top),  # Close at top
    ]

    # Draw 'L' with gradient
    # Create a temporary image for the 'L' shape
    l_mask = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    l_draw = ImageDraw.Draw(l_mask)
    l_draw.polygon(points, fill=(255, 255, 255, 255))

    # Composite gradient onto 'L' shape
    l_final = Image.alpha_composite(
        Image.new('RGBA', (width, height), (0, 0, 0, 0)),
        gradient_img.convert('RGBA')
    )
    l_final = Image.composite(l_final, Image.new('RGBA', (width, height)), l_mask.split()[-1])

    return l_final


def create_glass_card(size, blur_radius=40, opacity=25, border_opacity=40):
    """
    Create a frosted glass card effect.

    Args:
        size: Tuple (width, height)
        blur_radius: Gaussian blur radius
        opacity: Fill opacity percentage (0-100)
        border_opacity: Border opacity percentage (0-100)

    Returns:
        PIL Image with glass card effect
    """
    width, height = size

    # Card dimensions
    card_size = int(min(width, height) * 0.80)  # 80% of canvas
    corner_radius = int(card_size * 0.225)  # 22.5% of card width

    # Create card image
    card = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)

    # Card position (centered)
    card_left = (width - card_size) // 2
    card_top = (height - card_size) // 2
    card_right = card_left + card_size
    card_bottom = card_top + card_size

    # Draw rounded rectangle
    alpha = int(255 * opacity / 100)
    draw.rounded_rectangle(
        [(card_left, card_top), (card_right, card_bottom)],
        radius=corner_radius,
        fill=(255, 255, 255, alpha),
        outline=(255, 255, 255, int(255 * border_opacity / 100)),
        width=2
    )

    # Apply blur
    card_blurred = card.filter(ImageFilter.GaussianBlur(radius=blur_radius))

    return card_blurred


def create_app_icon(mode='light', output_path='app-icon.png'):
    """
    Create a complete glass morphism app icon.

    Args:
        mode: 'light' or 'dark'
        output_path: Where to save the icon

    Returns:
        PIL Image of the complete icon
    """
    print(f"🎨 Creating {mode} mode app icon...")

    # Canvas size
    size = (1024, 1024)

    # Background color
    bg_color = (255, 255, 255) if mode == 'light' else (0, 0, 0)

    # Glass card opacity
    glass_opacity = 25 if mode == 'light' else 30
    border_opacity = 40 if mode == 'light' else 50

    # Create background layer
    background = Image.new('RGB', size, bg_color)
    background_rgba = background.convert('RGBA')

    # Create glass card layer
    glass_card = create_glass_card(
        size,
        blur_radius=40,
        opacity=glass_opacity,
        border_opacity=border_opacity
    )

    # Create gradient for 'L' symbol
    gradient = create_gradient_color(
        size,
        color_start=(99, 102, 241),   # #6366F1 Indigo 500
        color_middle=(236, 72, 153),  # #EC4899 Pink 500
        color_end=(139, 92, 246)      # #8B5CF6 Violet 500
    )

    # Create fluid 'L' symbol
    fluid_l = create_fluid_L(size, gradient)

    # Create noise texture
    noise = create_noise_texture(size[0], size[1], opacity=5)

    # Composite all layers (back to front)
    # 1. Background
    icon = background_rgba.copy()

    # 2. Glass card
    icon = Image.alpha_composite(icon, glass_card)

    # 3. Fluid 'L' symbol
    icon = Image.alpha_composite(icon, fluid_l)

    # 4. Noise overlay
    icon = Image.alpha_composite(icon, noise)

    # Convert to RGB (remove alpha for App Store)
    icon_rgb = Image.new('RGB', size, bg_color)
    icon_rgb.paste(icon, mask=icon.split()[-1])

    # Save
    icon_rgb.save(output_path, 'PNG', quality=95)
    print(f"  ✓ Saved to {output_path}")

    return icon_rgb


def main():
    """Main function."""
    print("🎨 LexiconFlow App Icon Generator")
    print("   Creating glass morphism icon with fluid 'L' symbol\n")

    # Create output directory
    output_dir = "LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)

    # Generate light mode icon
    light_path = os.path.join(output_dir, "app-icon.png")
    create_app_icon(mode='light', output_path=light_path)

    # Generate dark mode icon
    dark_path = os.path.join(output_dir, "app-icon-dark.png")
    create_app_icon(mode='dark', output_path=dark_path)

    print("\n✅ App icons created successfully!")
    print(f"📂 Light mode: {light_path}")
    print(f"📂 Dark mode: {dark_path}")
    print("\nNext steps:")
    print("  1. Review icons visually")
    print("  2. Generate all iOS size variants:")
    print("     python3 scripts/generate-icon-variants.py --input LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/app-icon.png")
    print("  3. Test in iOS Simulator")


if __name__ == "__main__":
    main()
