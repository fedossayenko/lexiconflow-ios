# App Icon Design Specification

## Complete Technical Specifications

This document provides the exact technical specifications for the Lexicon Flow app icon design. All measurements are precise and ready for implementation.

---

## Canvas Specifications

```
Property: Value
─────────────────────────────────────
Width: 1024px
Height: 1024px
DPI: 72 (standard for screen)
Color Space: sRGB
Bit Depth: 32-bit (with alpha channel)
Format: PNG-24
File Size Target: < 500KB
Background: Opaque (no transparency)
```

---

## Layout Coordinates

### Center Point

```
Canvas Center: (512px, 512px)
```

### Glass Card

```
Property: Value
─────────────────────────────────────
Width: 819px
Height: 819px
X Position: 102.5px
Y Position: 102.5px
Corner Radius: 180px
Percentage of Canvas: 80%
```

**Verification**:
- Left edge: 102.5px from left
- Right edge: 921.5px from left (102.5 + 819)
- Top edge: 102.5px from top
- Bottom edge: 921.5px from top (102.5 + 819)
- Center: (512px, 512px) ✓

### Letter "L"

```
Property: Value
─────────────────────────────────────
Total Height: 716px
Total Width: ~686px
Stem Width: 123px
Stem Height: 716px
Crossbar Width: 563px
Crossbar Height: 123px
Crossbar Position: Extends from bottom of stem
Center Position: Aligned with glass card center (512px, 512px)
```

**Component Breakdown**:
- **Vertical Stem**:
  - Width: 123px
  - Height: 716px
  - X position: ~269px (centered within 819px glass card)
  - Y position: ~154px (centered vertically)

- **Horizontal Crossbar**:
  - Width: 563px
  - Height: 123px
  - X position: ~269px (aligned with stem)
  - Y position: ~747px (bottom of stem)

---

## Color Specifications

### Primary Palette

| Color Name | Hex Code | RGB (Decimal) | RGB (Percent) | Usage |
|------------|----------|---------------|---------------|-------|
| Indigo 500 | `#6366F1` | rgb(99, 102, 241) | rgb(38.8%, 40%, 94.5%) | Gradient start |
| Pink 500 | `#EC4899` | rgb(236, 72, 153) | rgb(92.5%, 28.2%, 60%) | Gradient middle |
| Purple 500 | `#8B5CF6` | rgb(139, 92, 246) | rgb(54.5%, 36.1%, 96.5%) | Gradient end |
| White (100%) | `#FFFFFF` | rgb(255, 255, 255) | rgb(100%, 100%, 100%) | Letter "L" fill |
| Glass Card (25%) | `#FFFFFF` | rgb(255, 255, 255, 0.25) | rgb(100%, 100%, 100%, 25%) | Glass card fill |
| Border (40%) | `#FFFFFF` | rgb(255, 255, 255, 0.40) | rgb(100%, 100%, 100%, 40%) | Glass card stroke |
| Drop Shadow | `#000000` | rgb(0, 0, 0, 0.15) | rgb(0%, 0%, 0%, 15%) | Glass card shadow |
| Letter Shadow | `#000000` | rgb(0, 0, 0, 0.25) | rgb(0%, 0%, 0%, 25%) | "L" drop shadow |

### Dark Mode Variant (Optional)

| Color Name | Hex Code | RGB (Decimal) | Usage |
|------------|----------|---------------|-------|
| Indigo 600 | `#4F46E5` | rgb(79, 70, 229) | Dark gradient start |
| Pink 600 | `#DB2777` | rgb(219, 39, 119) | Dark gradient middle |
| Purple 600 | `#7C3AED` | rgb(124, 58, 237) | Dark gradient end |

---

## Gradient Specifications

### Background Gradient

```
Type: Linear
Angle: 135° (diagonal from top-left to bottom-right)
Color Space: sRGB
Dither: Enabled (optional, for smoother gradients)

Gradient Stops:
─────────────────────────────────────────────────────────
Position: 0%
Color: #6366F1 (Indigo 500)
RGB: rgb(99, 102, 241)

Position: 50%
Color: #EC4899 (Pink 500)
RGB: rgb(236, 72, 153)

Position: 100%
Color: #8B5CF6 (Purple 500)
RGB: rgb(139, 92, 246)
```

**Gradient Flow Visualization**:
```
Top-Left (0,0)     Bottom-Right (1024,1024)
    #6366F1  ──────────────────────▶  #8B5CF6
              (50%, 50%)
                 #EC4899
```

### Top Highlight Gradient (Optional Enhancement)

```
Type: Linear
Angle: 90° (vertical, from top to bottom)
Height: 100px

Gradient Stops:
─────────────────────────────────────────────────────────
Position: 0%
Color: rgba(255, 255, 255, 0.3)

Position: 100%
Color: rgba(255, 255, 255, 0) (transparent)
```

---

## Glass Morphism Effects

### Glass Card Layer

```
Layer Type: Rectangle
Dimensions: 819x819px
Corner Radius: 180px

Fill:
  Type: Solid
  Color: #FFFFFF
  Opacity: 25%

Stroke:
  Type: Inside (or Center)
  Width: 2px
  Color: #FFFFFF
  Opacity: 40%

Effects (in order):
  1. Background Blur: 40px Gaussian
  2. Drop Shadow:
     - X Offset: 0px
     - Y Offset: 20px
     - Blur: 60px
     - Spread: 0px
     - Color: rgba(0, 0, 0, 0.15)
  3. Inner Shadow:
     - X Offset: 0px
     - Y Offset: 2px
     - Blur: 8px
     - Color: rgba(255, 255, 255, 0.4)
```

### Noise Texture (Optional Enhancement)

```
Layer Type: Rectangle
Dimensions: 819x819px (same as glass card)
Fill: Transparent

Effects:
  - Noise: 5% amount
  - Blend Mode: Overlay
  - Mask: Clipped to glass card
```

### Letter "L" Layer

```
Layer Type: Custom Shape (union of two rectangles)

Fill:
  Type: Solid
  Color: #FFFFFF
  Opacity: 100%

Effects:
  Drop Shadow:
    - X Offset: 0px
    - Y Offset: 4px
    - Blur: 12px
    - Spread: 0px
    - Color: rgba(0, 0, 0, 0.25)
```

---

## Layer Order

**Bottom to Top**:

```
1. Background Gradient Layer
   - Rectangle: 1024x1024px
   - Fill: Linear gradient (135°, #6366F1 → #EC4899 → #8B5CF6)
   - Effect: Layer Blur 40px (optional, for softer gradient)

2. Glass Card Layer
   - Rectangle: 819x819px, centered
   - Fill: White 25% opacity
   - Stroke: 2px white 40% opacity
   - Effects: Background blur 40px, drop shadow, inner shadow

3. Letter "L" Layer
   - Custom shape (stem + crossbar)
   - Fill: White 100% opacity
   - Effect: Drop shadow 0px, 4px, 12px, rgba(0,0,0,0.25)

4. Top Highlight Layer (optional)
   - Rectangle: 819x100px, top-aligned
   - Fill: Linear gradient (90°, rgba(255,255,255,0.3) → transparent)
   - Blend Mode: Screen or Overlay

5. Noise Texture Layer (optional)
   - Rectangle: 819x819px
   - Effect: Noise 5%
   - Blend Mode: Overlay
   - Mask: Clipped to glass card
```

---

## Typography Specifications

### Letter "L" Font Reference

If using text instead of vector shapes:

```
Font Family: SF Pro Display
Font Weight: Bold (700) or Heavy (800)
Font Size: ~700px (adjust to fit 716px height)
Tracking: 0 (default)
Line Height: 100%

Alternative Fonts (if SF Pro Display not available):
  - Helvetica Neue Bold
  - Inter Bold
  - Roboto Bold
  - Arial Bold (fallback)
```

**Note**: Using vector shapes (two rectangles unioned) is recommended over text for precise control and consistency across platforms.

---

## Export Specifications

### Export Settings

```
Format: PNG
Color Depth: 24-bit RGB + 8-bit alpha (32-bit total)
Color Profile: sRGB IEC61966-2.1
DPI: 72 (screen resolution)
Compression: None (lossless)
Transparency: No (opaque background)
Metadata: None (exclude EXIF, etc.)
Interlaced: No

File Naming Convention:
  AppIcon-1024.png
  or
  lexicon-flow-app-icon-1024.png
```

### File Size Targets

```
Optimal: 200-400KB
Acceptable: 400-500KB
Maximum: 1MB (optimize if larger)
```

### Quality Verification

After export, verify:

```bash
# Using file command (macOS/Linux)
file AppIcon-1024.png
# Expected output: PNG image data, 1024 x 1024, 8-bit/color RGB

# Using mdls (macOS)
mdls AppIcon-1024.png | grep PixelWidth
# Expected output: PixelWidth = 1024

mdls AppIcon-1024.png | grep PixelHeight
# Expected output: PixelHeight = 1024

mdls AppIcon-1024.png | grep ColorSpace
# Expected output: ColorSpace = "RGB"

# Check file size
ls -lh AppIcon-1024.png
# Expected output: ~200-500KB
```

---

## Scaling Guidelines

### Automatic Generation (iOS 11+)

For iOS 11 and later, **only the 1024x1024 master icon is required**. iOS automatically generates all other sizes from this master.

**Recommended**: Use this universal approach for simplicity.

### Explicit Sizes (If Needed)

If automatic generation causes issues at small sizes, create explicit icons for:

| Size | Usage | Adjustments |
|------|-------|-------------|
| 16x16 | Notification Center, Document Outline | Thicken stroke by 20%, reduce blur to 20px |
| 29x29 | Settings | No changes needed |
| 32x32 | Mac Finder | No changes needed |
| 40x40 | iPhone Spotlight | No changes needed |
| 58x58 | Settings @2x | No changes needed |
| 60x60 | iPhone App @2x | No changes needed |
| 76x76 | iPad App | No changes needed |
| 80x80 | iPhone Spotlight @2x | No changes needed |
| 87x87 | iPhone Notification @3x | No changes needed |
| 120x120 | iPhone App @2x | No changes needed |
| 152x152 | iPad App @2x | No changes needed |
| 167x167 | iPad Pro App @2x | No changes needed |
| 180x180 | iPhone App @3x | No changes needed |
| 1024x1024 | App Store | Master icon, no changes |

**Size-Specific Adjustments** (for icons < 60x60):
1. Thicken "L" stroke by 20-30%
2. Reduce Gaussian blur from 40px to 20-25px
3. Simplify shadow blur from 12px to 6-8px
4. Increase glass card opacity from 25% to 35-40%

---

## Xcode Integration

### Asset Catalog Placement

```
Path: LexiconFlow/Assets.xcassets/AppIcon/
Structure:
  AppIcon/
    ├── AppIcon-1024.png (1024x1024)
    ├── Contents.json (auto-generated)
    └── (iOS automatically generates other sizes)
```

### Contents.json Example

```json
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

### Adding to Xcode Project

1. Open `LexiconFlow.xcodeproj`
2. Navigate to `Assets.xcassets`
3. Select `AppIcon` asset
4. Drag `AppIcon-1024.png` to the 1024x1024 slot
5. Xcode automatically generates all other required sizes

---

## Accessibility & Testing

### Accessibility Check

After adding the icon to the project, verify in all contexts:

```swift
// Test icon appearance in different contexts:
- Home Screen (60x60 to 180x180)
- Settings App (29x29 to 87x87)
- Notification Center (16x16 to 40x40)
- Spotlight Search (40x40 to 120x120)
- App Store (1024x1024 scaled down)
```

### Device Testing Checklist

- [ ] iPhone SE (small display)
- [ ] iPhone 15 (standard display)
- [ ] iPhone 15 Pro Max (large display)
- [ ] iPad (standard display)
- [ ] iPad Pro 12.9" (large display)

### Context Testing Checklist

- [ ] Home screen (light mode)
- [ ] Home screen (dark mode)
- [ ] Settings app
- [ ] Search results
- [ ] Notifications
- [ ] App Store listing

---

## Comparison with Current Icon

### Existing Icon Analysis

The project currently has `app-icon.png` and `app-icon-dark.png` in the Assets.xcassets:

**Current Design**: Jellyfish illustration
**Style**: Flat colors, simple illustration
**Issue**: Does not match Liquid Glass aesthetic

**Recommended Action**:
Replace with glass morphism "L" icon designed in this specification.

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-06 | Initial specification |

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Related Documents**:
- `app-icon-design-concept.md` (design philosophy and rationale)
- `app-icon-visual-reference.md` (annotated visual diagrams)
- `app-icon-implementation-guide.md` (tool-specific instructions)
- `app-icon-designer-brief.md` (instructions for designers)
