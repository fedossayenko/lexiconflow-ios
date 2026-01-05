# App Icon Variants Guide

## Overview

This guide explains how to generate all required iOS app icon sizes from the 1024x1024 master icon, including automated approaches and manual optimizations.

## Key Recommendation: Universal Icon (iOS 11+)

**For iOS 11 and later, only the 1024x1024 master icon is required.**

iOS automatically generates all other sizes from the master using high-quality downscaling. This is the **recommended approach** for most apps.

### When to Use Universal Icon

✅ **Use Universal Icon (single 1024x1024 master) if**:
- Targeting iOS 11+ only
- Icon design is simple and scales well
- No critical issues at small sizes
- Want simplest workflow

❌ **Create explicit sizes if**:
- Supporting iOS 10 or earlier (rare in 2026)
- Icon has small details that get lost at 16x16 or 29x29
- Accessibility concerns at small sizes
- Need pixel-perfect control at every size

---

## All iOS Icon Sizes

### Required Sizes (iOS 11+ Universal)

| Size | Usage | Platform | Required? |
|------|-------|----------|-----------|
| 1024x1024 | App Store | All | ✅ **Required** |
| Auto-generated | All other sizes | iOS 11+ | ✅ Automatic |

### Explicit Sizes (Reference Only)

| Size | Usage | Platform | Notes |
|------|-------|----------|-------|
| 16x16 | Notification Center, Document Outline | macOS | Optional |
| 29x29 | Settings | iOS | Auto-generated |
| 32x32 | Finder | macOS | Optional |
| 40x40 | iPhone Spotlight | iOS | Auto-generated |
| 58x58 | Settings @2x | iOS | Auto-generated |
| 60x60 | iPhone App @2x | iOS | Auto-generated |
| 76x76 | iPad App | iOS | Auto-generated |
| 80x80 | iPhone Spotlight @2x | iOS | Auto-generated |
| 87x87 | iPhone Notification @3x | iOS | Auto-generated |
| 120x120 | iPhone App @2x | iOS | Auto-generated |
| 152x152 | iPad App @2x | iOS | Auto-generated |
| 167x167 | iPad Pro App @2x | iOS | Auto-generated |
| 180x180 | iPhone App @3x | iOS | Auto-generated |

---

## Size-Specific Adjustments

### Small Icons (16x16, 29x29, 32x32)

**Challenge**: Glass morphism effects become invisible at small sizes

**Adjustments**:
1. **Thicken "L" stroke**: Increase by 20-30%
2. **Reduce blur**: Decrease from 40px to 20-25px
3. **Simplify shadow**: Reduce blur from 12px to 6-8px
4. **Increase opacity**: Glass card from 25% to 35-40%

**Before (1024x1024)**:
- Glass blur: 40px
- "L" shadow: 12px blur
- Glass opacity: 25%

**After (16x16 or 29x29)**:
- Glass blur: 20-25px
- "L" shadow: 6-8px blur
- Glass opacity: 35-40%

### Medium Icons (40x40 to 87x87)

**No adjustments needed** - auto-generated icons typically look good.

### Large Icons (120x120 to 1024x1024)

**No adjustments needed** - full detail visible.

---

## Automated Generation Tools

### Option 1: Xcode Asset Catalog (Recommended)

**How it works**:
1. Add 1024x1024 icon to Asset Catalog
2. Xcode automatically generates all sizes
3. No manual intervention needed

**Steps**:
```
1. Open LexiconFlow.xcodeproj
2. Navigate to Assets.xcassets
3. Select AppIcon
4. Drag AppIcon-1024.png to 1024x1024 slot
5. Build and run - Xcode generates all sizes automatically
```

**Pros**:
- Zero effort
- Apple's downscaling algorithm
- Automatically stays updated
- No manual maintenance

**Cons**:
- Less control over small icon appearance
- Can't optimize specific sizes

### Option 2: macOS sips Command (Built-in)

**sips** (Scriptable Image Processing System) is built into macOS.

**Generate all sizes with shell script**:
```bash
#!/bin/bash
# generate-icon-variants.sh

MASTER_ICON="AppIcon-1024.png"
OUTPUT_DIR="icon-variants"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Array of sizes to generate
SIZES=(16 29 32 40 58 60 76 80 87 120 152 167 180)

# Generate each size
for size in "${SIZES[@]}"; do
    sips -z "$size" "$size" "$MASTER_ICON" --out "$OUTPUT_DIR/AppIcon-${size}x${size}.png"
done

echo "Generated ${#SIZES[@]} icon variants in $OUTPUT_DIR"
```

**Usage**:
```bash
chmod +x generate-icon-variants.sh
./generate-icon-variants.sh
```

### Option 3: ImageMagick (Cross-platform)

**Install ImageMagick**:
```bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick
```

**Generate all sizes**:
```bash
#!/bin/bash
# generate-icon-variants-imagemagick.sh

MASTER="AppIcon-1024.png"
OUTPUT_DIR="icon-variants"

mkdir -p "$OUTPUT_DIR"

SIZES=(16 29 32 40 58 60 76 80 87 120 152 167 180)

for size in "${SIZES[@]}"; do
    convert "$MASTER" -resize "${size}x${size}" "$OUTPUT_DIR/AppIcon-${size}x${size}.png"
done

echo "Generated ${#SIZES[@]} icon variants"
```

### Option 4: Python with Pillow (Cross-platform)

**See**: `scripts/generate-icon-variants.py` (included in this project)

**Usage**:
```bash
python3 scripts/generate-icon-variants.py AppIcon-1024.png icon-variants
```

---

## Manual Generation (Design Tools)

### Figma: Auto-Layout

1. Create master icon frame (1024x1024)
2. Create variants for different sizes:
   - Right-click frame → Create Variants
   - Add properties: Size (16, 29, 40, etc.)
   - Adjust layer properties per size (thicken stroke, reduce blur)
3. Export all variants at once

### Sketch: Shared Styles

1. Create master icon
2. Duplicate artboard for each size
3. Adjust properties per size
4. Export all artboards

### Adobe Photoshop: Actions

1. Open master icon
2. Create Action: "Generate Icon Variants"
3. Record: Image Size → Resize → Save
4. Batch process all sizes

---

## Quality Verification

### Automated Verification Script

See `scripts/validate_app_store_assets.py` for automated verification.

### Manual Verification Checklist

For each generated size:

- [ ] Icon is centered
- [ ] "L" is clearly visible
- [ ] Colors are correct
- [ ] No pixelation or artifacts
- [ ] File size is reasonable
- [ ] Transparent areas are correct (should be opaque)

### Visual Testing

Test icons in context:

```bash
# Test in Xcode
1. Add icons to Asset Catalog
2. Run on device/simulator
3. Check Home screen, Settings, Spotlight
4. Verify appearance at all sizes
```

---

## Troubleshooting

### Small Icons Look Blurry

**Problem**: Auto-generated 16x16 or 29x29 icons are blurry

**Solutions**:
1. Create explicit versions with thicker strokes
2. Reduce blur effects at small sizes
3. Increase glass card opacity for better contrast
4. Test on actual device, not just simulator

### Colors Look Different

**Problem**: Generated icons have different colors than master

**Solutions**:
1. Verify color profile is sRGB (not Display P3)
2. Check export settings in design tool
3. Re-export with correct color profile
4. Use ImageMagick with `-colorspace sRGB`

### Icons Have Transparency

**Problem**: Generated icons have transparent backgrounds

**Solutions**:
1. Ensure master icon has opaque background
2. Add background fill layer before export
3. Use `convert -flatten` in ImageMagick
4. Check "opaque" option in export settings

### File Size Too Large

**Problem**: Generated icons are > 100KB each

**Solutions**:
1. Reduce complexity (fewer effects)
2. Optimize with ImageOptim (Mac) or TinyPNG (web)
3. Use 8-bit color instead of 32-bit (if quality acceptable)
4. Reduce resolution (unlikely to help much)

---

## Best Practices

### 1. Start with Master

Always create the 1024x1024 master first, then generate smaller sizes. This ensures consistency.

### 2. Test Early, Test Often

Generate test variants early in the design process to check how the icon scales.

### 3. Use Version Control

Keep icon files in Git (they're small enough) to track changes.

### 4. Document Exceptions

If you create explicit sizes for 16x16 or 29x29, document why and what adjustments were made.

### 5. Automate When Possible

Use scripts or design tool features to automate generation and avoid manual errors.

### 6. Optimize for Accessibility

Ensure small icons are readable for users with visual impairments (higher contrast, simpler design).

---

## Xcode Asset Catalog Structure

```
LexiconFlow/
  Assets.xcassets/
    AppIcon.appiconset/
      ├── AppIcon-1024.png (1024x1024)
      └── Contents.json

Contents.json (iOS 11+ universal):
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

---

## Quick Reference

### Universal Icon (Recommended)

```
Master: 1024x1024
Other sizes: Auto-generated by iOS
Workflow: Add to Asset Catalog → Done
```

### Explicit Sizes (If Needed)

```
Tools: sips, ImageMagick, Python/Pillow
Script: scripts/generate-icon-variants.sh or .py
Output: icon-variants/ directory with all sizes
```

### Verification

```
Script: scripts/validate_app_store_assets.py
Command: python3 scripts/validate_app_store_assets.py
Check: All sizes exist, correct dimensions, reasonable file size
```

---

## Related Documents

- `app-icon-design-concept.md` - Design philosophy and specifications
- `app-icon-implementation-guide.md` - Tool-specific creation instructions
- `scripts/generate-icon-variants.py` - Python automation script
- `scripts/generate-icon-variants.sh` - Shell automation script

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Recommendation**: Use universal icon approach (iOS 11+) for simplicity
