# App Icon Variants Guide

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Purpose**: Guide for generating all iOS icon size variants from 1024×1024 master

---

## Overview

The iOS platform requires app icons at multiple sizes for different contexts (home screen, settings, spotlight, notifications, etc.). This guide explains how to generate all 16 required variants from a single 1024×1024 master icon.

---

## Size Variant Reference

### Complete Size Table

| **Export Size** | **Display Size** | **Scale** | **Platform** | **Context** | **Filename** |
|-----------------|------------------|-----------|--------------|-------------|--------------|
| 1024×1024 | 1024×1024 | 1x | iOS Universal | App Store | `app-icon-1024.png` |
| 512×512 | 512×512 | 1x | macOS | Mac App Store | `app-icon-512.png` |
| 256×256 | 256×256 | 1x | macOS | Retina Display | `app-icon-256.png` |
| 128×128 | 128×128 | 1x | macOS | Standard Display | `app-icon-128.png` |
| 128×128 | 64×64 | 2x | iOS Universal | Spotlight | `app-icon-64@2x.png` |
| 120×120 | 60×60 | 2x | iPhone | App Icon (Retina) | `app-icon-60@2x.png` |
| 180×180 | 60×60 | 3x | iPhone | App Icon (Retina HD) | `app-icon-60@3x.png` |
| 80×80 | 40×40 | 2x | iPad | App Icon (Retina) | `app-icon-40@2x.png` |
| 120×120 | 40×40 | 3x | iPad Pro | App Icon (Retina HD) | `app-icon-40@3x.png` |
| 58×58 | 29×29 | 2x | iOS Universal | Settings (Retina) | `app-icon-29@2x.png` |
| 87×87 | 29×29 | 3x | iOS Universal | Settings (Retina HD) | `app-icon-29@3x.png` |
| 40×40 | 20×20 | 2x | iOS Universal | Notifications (Retina) | `app-icon-20@2x.png` |
| 60×60 | 20×20 | 3x | iOS Universal | Notifications (Retina HD) | `app-icon-20@3x.png` |
| 16×16 | 16×16 | 1x | macOS | Info.plist | `app-icon-16.png` |

**Total**: 14 variants (excluding dark mode duplicates)

---

## Generation Methods

### Method 1: Figma Plugin (Recommended)

**Plugin**: App Icon Generator by Thomas D.

#### Steps:

1. **Install Plugin**
   - In Figma, go to **Resources → Community**
   - Search: "App Icon Generator"
   - Click **Install**

2. **Prepare Design**
   - Create 1024×1024 frame with icon
   - Ensure frame is named: "App Icon"

3. **Run Plugin**
   - Select "App Icon" frame
   - Right-click → **Plugins → App Icon Generator**
   - Select **iOS** platform
   - Choose export location
   - Click **Generate Icons**

4. **Review Output**
   - Plugin creates all iOS sizes automatically
   - Files named per Apple convention
   - Ready for Xcode integration

**Pros**: Fast, automated, handles naming
**Cons**: Requires Figma, plugin dependency

---

### Method 2: Manual Export from Figma/Sketch

#### Figma Steps:

1. **Select Frame**
   - Click "App Icon" frame

2. **Add Export Settings**
   - In right sidebar, click **+** next to "Export"
   - Add each size setting:

   ```
   1x: 1024, PNG
   1x: 512, PNG
   1x: 256, PNG
   1x: 128, PNG
   2x: 64, PNG
   2x: 60, PNG
   3x: 60, PNG
   2x: 40, PNG
   3x: 40, PNG
   2x: 29, PNG
   3x: 29, PNG
   2x: 20, PNG
   3x: 20, PNG
   1x: 16, PNG
   ```

3. **Export All**
   - Click **Export [App Icon]**
   - Choose destination folder
   - Figma exports all sizes at once

4. **Rename Files** (if needed)
   - Figma names: `App Icon@1x.png`, `App Icon@2x.png`, etc.
   - Rename to: `app-icon-1024.png`, `app-icon-60@2x.png`, etc.

**Pros**: No plugins, manual control
**Cons**: Time-consuming, must rename files

---

### Method 3: Python Script (Cross-Platform)

**Script**: `scripts/generate-icon-variants.py`

#### Prerequisites:

```bash
# Install Pillow (Python Image Library)
pip3 install Pillow
```

#### Usage:

```bash
# From project root
python3 scripts/generate-icon-variants.py \
  --input docs/app-icon-1024.png \
  --output LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/ \
  --format ios
```

#### What It Does:

1. Loads 1024×1024 master PNG
2. Resizes to each iOS size using high-quality Lanczos resampling
3. Saves with correct filenames per Apple HIG
4. Creates directory structure if needed
5. Generates manifest file (Contents.json)

**Pros**: Automated, cross-platform, scriptable
**Cons**: Requires Python, must write script first

---

### Method 4: ImageMagick (Command Line)

**Tool**: ImageMagick (install via Homebrew)

```bash
# Install ImageMagick
brew install imagemagick
```

#### Bash Script:

```bash
#!/bin/bash
# generate-icon-variants.sh

INPUT="app-icon.png"
OUTPUT_DIR="LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Resize to each size (high-quality)
convert "$INPUT" -resize 1024x1024 "$OUTPUT_DIR/app-icon-1024.png"
convert "$INPUT" -resize 512x512 "$OUTPUT_DIR/app-icon-512.png"
convert "$INPUT" -resize 256x256 "$OUTPUT_DIR/app-icon-256.png"
convert "$INPUT" -resize 128x128 "$OUTPUT_DIR/app-icon-128.png"
convert "$INPUT" -resize 128x128 "$OUTPUT_DIR/app-icon-64@2x.png"
convert "$INPUT" -resize 120x120 "$OUTPUT_DIR/app-icon-60@2x.png"
convert "$INPUT" -resize 180x180 "$OUTPUT_DIR/app-icon-60@3x.png"
convert "$INPUT" -resize 80x80 "$OUTPUT_DIR/app-icon-40@2x.png"
convert "$INPUT" -resize 120x120 "$OUTPUT_DIR/app-icon-40@3x.png"
convert "$INPUT" -resize 58x58 "$OUTPUT_DIR/app-icon-29@2x.png"
convert "$INPUT" -resize 87x87 "$OUTPUT_DIR/app-icon-29@3x.png"
convert "$INPUT" -resize 40x40 "$OUTPUT_DIR/app-icon-20@2x.png"
convert "$INPUT" -resize 60x60 "$OUTPUT_DIR/app-icon-20@3x.png"
convert "$INPUT" -resize 16x16 "$OUTPUT_DIR/app-icon-16.png"

echo "Generated 14 icon variants in $OUTPUT_DIR"
```

**Pros**: Fast, scriptable, no Python
**Cons**: Requires ImageMagick, quality slightly lower than Pillow

---

## Quality Considerations

### Resampling Algorithms

When resizing icons, use the right algorithm:

| Algorithm | Quality | Speed | Best For |
|-----------|---------|-------|----------|
| **Nearest Neighbor** | ⭐ (worst) | ⚡️ (fastest) | Pixel art only |
| **Bilinear** | ⭐⭐ | ⚡️⚡️ | Quick previews |
| **Bicubic** | ⭐⭐⭐ | ⚡️⚡️ | General use |
| **Lanczos** | ⭐⭐⭐⭐⭐ (best) | ⚡️⚡️⚡️ (slow) | **Icon resizing (RECOMMENDED)** |

**Recommended**: Use Lanczos resampling for all icon sizes.

### File Size Optimization

After generating variants, optimize PNGs:

```bash
# Install pngcrush
brew install pngcrush

# Optimize all PNGs
find . -name "*.png" -exec pngcrush -brute {} {}.optimized \;
mv {}.optimized {}  # Replace originals

# Or use optipng (faster)
brew install optipng
find . -name "*.png" -exec optipng -o7 {} \;
```

**Typical savings**: 10-30% file size reduction without quality loss.

---

## Dark Mode Variants

### Generating Dark Mode Icons

Repeat any of the above methods using the dark mode master (`app-icon-dark.png`):

**Naming Convention**: Append `-dark` suffix

```
app-icon-1024-dark.png
app-icon-60@2x-dark.png
app-icon-29@3x-dark.png
...
```

### Asset Catalog Setup

In Xcode's asset catalog, create separate data sets:

```
AppIcon.appiconset/
├── AppIcon (light mode)
│   ├── app-icon-1024.png
│   ├── app-icon-60@2x.png
│   └── ...
└── AppIcon Dark (dark mode)
    ├── app-icon-1024-dark.png
    ├── app-icon-60@2x-dark.png
    └── ...
```

---

## Integration with Xcode

### Manual Integration

1. **Copy Files to Asset Catalog**
   ```bash
   cp app-icon-*.png LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/
   ```

2. **Update Contents.json**
   ```json
   {
     "images" : [
       {
         "filename" : "app-icon-1024.png",
         "idiom" : "universal",
         "platform" : "ios",
         "size" : "1024x1024"
       },
       {
         "filename" : "app-icon-60@2x.png",
         "idiom" : "iphone",
         "scale" : "2x",
         "size" : "60x60"
       }
       // ... all other sizes
     ],
     "info" : {
       "author" : "xcode",
       "version" : 1
     }
   }
   ```

3. **Verify in Xcode**
   - Open `Assets.xcassets`
   - Select `AppIcon`
   - Verify all sizes appear correctly

### Script Integration (Automated)

Use provided script to auto-generate Contents.json:

```bash
python3 scripts/generate-icon-variants.py \
  --input app-icon.png \
  --output LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/ \
  --update-contents-json
```

---

## Validation

### Check File Existence

```bash
cd LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/

# Count PNG files
ls -1 *.png | wc -l
# Expected: 14 (or 28 including dark mode)

# List all sizes
ls -lh *.png
```

### Verify Dimensions

```bash
# Check each file's dimensions
for file in *.png; do
  echo "$file: $(sips -g pixelWidth -g pixelHeight "$file" | grep -E 'pixelWidth|pixelHeight')"
done
```

### Test in Simulator

1. Clean build folder: **Cmd+Shift+K**
2. Delete app from simulator
3. Rebuild and run: **Cmd+R**
4. Check icon on home screen
5. Check icon in Settings app
6. Check icon in Spotlight search

---

## Common Issues

### Issue 1: Icons Look Blurry at Small Sizes

**Cause**: Wrong resampling algorithm

**Solution**:
- Ensure using Lanczos resampling
- In Figma: Export at 2x or 3x scale, then let Xcode downscale
- In Python: Use `Image.LANCZOS` in Pillow

### Issue 2: Wrong Filenames

**Cause**: Naming convention mismatch

**Solution**:
- Use Apple's HIG convention: `app-icon-{size}@{scale}x.png`
- Examples:
  - ✅ `app-icon-60@2x.png` (correct)
  - ❌ `icon-60-2x.png` (wrong)
  - ❌ `app-icon-120.png` (wrong - use @2x notation)

### Issue 3: Xcode Shows "Missing Reference"

**Cause**: Contents.json doesn't match actual filenames

**Solution**:
1. Compare Contents.json filenames with actual files
2. Update Contents.json to match
3. Or delete Contents.json and let Xcode regenerate

### Issue 4: Dark Mode Not Appearing

**Cause**: Asset catalog not configured for dark mode

**Solution**:
1. In Xcode's asset catalog, select AppIcon
2. In Attributes inspector, check "Appearances: Any, Dark"
3. Add dark mode variants to the "Dark" appearance
4. Ensure filenames have `-dark` suffix

---

## Best Practices

### 1. Always Start from 1024×1024 Master

- ✅ Do: Generate all sizes from 1024×1024
- ❌ Don't: Chain resize (e.g., 1024→512→256→128)

### 2. Use Lossless PNG

- ✅ Do: Export as PNG without compression
- ❌ Don't: Use JPEG (lossy compression)

### 3. Optimize After Export

- ✅ Do: Run pngcrush or optipng after generation
- ❌ Don't: Skip optimization (file sizes too large)

### 4. Test Smallest Size

- ✅ Do: Verify icon looks good at 16×16
- ❌ Don't: Only check 1024×1024 (App Store size)

### 5. Version Control

- ✅ Do: Commit all icon variants to git
- ❌ Don't: Only commit 1024×1024 master

---

## Automation Script

### Complete Generation Script

```bash
#!/bin/bash
# generate-all-icons.sh

set -e  # Exit on error

MASTER="app-icon.png"
MASTER_DARK="app-icon-dark.png"
OUTPUT_DIR="LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/"

echo "🎨 Generating iOS icon variants..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate light mode variants
echo "📱 Generating light mode icons..."
python3 scripts/generate-icon-variants.py \
  --input "$MASTER" \
  --output "$OUTPUT_DIR"

# Generate dark mode variants (if dark master exists)
if [ -f "$MASTER_DARK" ]; then
  echo "🌙 Generating dark mode icons..."
  python3 scripts/generate-icon-variants.py \
    --input "$MASTER_DARK" \
    --output "$OUTPUT_DIR" \
    --suffix "-dark"
fi

# Optimize PNGs
echo "⚡️ Optimizing PNG files..."
find "$OUTPUT_DIR" -name "*.png" -exec optipng -o7 {} \;

# Update Contents.json
echo "📝 Updating Contents.json..."
python3 scripts/generate-icon-variants.py \
  --output "$OUTPUT_DIR" \
  --update-contents-json

# Count generated files
COUNT=$(ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')

echo "✅ Generated $COUNT icon variants in $OUTPUT_DIR"
echo "🚀 Ready to build and test!"
```

**Usage**:
```bash
chmod +x generate-all-icons.sh
./generate-all-icons.sh
```

---

## Summary

**Recommended Workflow**:

1. Design icon in Figma (1024×1024)
2. Use Figma plugin "App Icon Generator"
3. Export to asset catalog folder
4. Optimize with optipng
5. Update Contents.json (automatic)
6. Test in Xcode simulator
7. Commit to git

**Time Estimate**: 30 minutes (including testing)

**Deliverables**: 14-28 icon files (light + dark mode)

---

**Document Control**

- **Author**: iOS Team
- **Status**: Ready for use
- **Related**: [app-icon-implementation-guide.md](./app-icon-implementation-guide.md)
