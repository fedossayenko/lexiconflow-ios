# App Icon Design Specification

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Purpose**: Technical specification for glass morphism app icon design and validation

---

## Specification Summary

This document provides exact specifications for LexiconFlow's glass morphism app icon, including precise measurements, color values, effect parameters, and validation criteria.

---

## 1. Canvas Specifications

### 1.1 Master Icon

| Property | Value | Tolerance |
|----------|-------|-----------|
| **Dimensions** | 1024 × 1024 pixels | ±0 pixels (exact) |
| **Color Space** | sRGB IEC61966-2.1 | Required |
| **Bit Depth** | 8-bit/channel (24-bit RGB) | Minimum |
| **DPI/PPI** | 72 (screen), 300 (print ref) | Not critical |
| **File Format** | PNG | Required |
| **Alpha Channel** | None (solid background) | Required for App Store |
| **Compression** | None (lossless PNG) | Required |
| **File Size** | < 500 KB | Maximum |

### 1.2 Background Layer

| Property | Value | Notes |
|----------|-------|-------|
| **Dimensions** | 1024 × 1024 pixels | Full canvas |
| **Color (Light)** | `#FFFFFF` (RGB 255,255,255) | Solid white |
| **Color (Dark)** | `#000000` (RGB 0,0,0) | Solid black |
| **Opacity** | 100% | No transparency |
| **Effects** | None | Flat color |

---

## 2. Glass Card Specifications

### 2.1 Geometry

| Property | Value | Calculation | Tolerance |
|----------|-------|-------------|-----------|
| **Width** | 819 pixels | 1024 × 0.80 | ±2 pixels |
| **Height** | 819 pixels | 1024 × 0.80 | ±2 pixels |
| **Position X** | 102.5 pixels | (1024 - 819) / 2 | ±1 pixel |
| **Position Y** | 102.5 pixels | (1024 - 819) / 2 | ±1 pixel |
| **Corner Radius** | 184.275 pixels | 819 × 0.225 | ±5 pixels |
| **Border Width** | 2 pixels | Fixed | ±0 pixels |

### 2.2 Fill Properties (Light Mode)

| Property | Value | Notes |
|----------|-------|-------|
| **Color** | `#FFFFFF` (RGB 255,255,255) | White |
| **Opacity** | 25% | ±2% tolerance |
| **Blend Mode** | Normal | Default |

### 2.3 Fill Properties (Dark Mode)

| Property | Value | Notes |
|----------|-------|-------|
| **Color** | `#FFFFFF` (RGB 255,255,255) | White |
| **Opacity** | 30% | ±2% tolerance |
| **Blend Mode** | Normal | Default |

### 2.4 Stroke/Border

| Property | Value | Notes |
|----------|-------|-------|
| **Color** | `#FFFFFF` (RGB 255,255,255) | White |
| **Opacity** | 40% (light), 50% (dark) | ±5% tolerance |
| **Width** | 2 pixels | Exact |
| **Position** | Inside/Center | Design tool choice |

### 2.5 Layer Blur Effect

| Property | Value | Notes |
|----------|-------|-------|
| **Type** | Gaussian Blur | Required |
| **Radius** | 40 pixels | ±5 pixels tolerance |
| **Quality** | High | Design tool default |
| **Edge Behavior** | Normal | Default |

---

## 3. Fluid 'L' Symbol Specifications

### 3.1 Geometry

| Property | Value | Notes |
|----------|-------|-------|
| **Height** | ~500 pixels | Scaled to fit glass card |
| **Width** | ~350 pixels | Proportional to height |
| **Position** | Centered | X: 512, Y: 512 |
| **Padding** | 159.5 pixels | (819 - 500) / 2 |

### 3.2 Stroke Properties

| Property | Value | Notes |
|----------|-------|-------|
| **Max Stroke Width** | 120 pixels | At thickest point (downstroke) |
| **Min Stroke Width** | 60 pixels | At thinnest point (crossbar) |
| **Stroke Taper** | Yes | Calligraphic: thick→thin |
| **Curve** | 5° inward | Slight bend for fluidity |

### 3.3 Gradient Fill

| Property | Value | Notes |
|----------|-------|-------|
| **Type** | Linear Gradient | Required |
| **Angle** | 45° | Diagonal, bottom-left to top-right |

#### Gradient Stops

| Stop | Color | Hex | RGB | Position |
|------|-------|-----|-----|----------|
| **Start** | Indigo 500 | `#6366F1` | RGB(99, 102, 241) | 0% |
| **Middle** | Pink 500 | `#EC4899` | RGB(236, 72, 153) | 50% |
| **End** | Violet 500 | `#8B5CF6` | RGB(139, 92, 246) | 100% |

**Gradient Interpolation**: Linear (default)
**Color Space**: sRGB

### 3.4 Calligraphic Guidelines

The 'L' should follow these proportions:

```
Vertical Stroke:
  ├─ Top width: 80px (tapered from 120px)
  ├─ Base width: 120px (thickest point)
  ├─ Height: 400px
  └─ Curve: 5° inward bend at top

Horizontal Crossbar:
  ├─ Width: 60px (uniform)
  ├─ Length: 250px (60% of vertical height)
  ├─ Position: 120px from top
  └─ Connection: Smooth, calligraphic join
```

---

## 4. Noise Texture Overlay

### 4.1 Texture Properties

| Property | Value | Notes |
|----------|-------|-------|
| **Dimensions** | 1024 × 1024 pixels | Full canvas |
| **Type** | Perlin or Gaussian Noise | Either acceptable |
| **Color** | Grayscale | Monochromatic |
| **Opacity** | 5% | ±1% tolerance |
| **Blend Mode** | Normal or Overlay | Either acceptable |

### 4.2 Noise Generation

**If using design tool**:
- Figma: Effects → Noise → 5%
- Sketch: Layer → Noise → 5%
- Illustrator: Effect → Texture → Grain

**If using noise image**:
- Resolution: 512 × 512 pixels (tiled)
- Bit depth: 8-bit grayscale
- Format: PNG with transparency

---

## 5. Layer Stack Order

### 5.1 Layer Order (Top to Bottom)

```
1. Noise Overlay (1024×1024, 5% opacity)
2. Fluid 'L' Symbol (centered, gradient)
3. Glass Card (819×819, 40px blur, 25% opacity)
4. Background (1024×1024, solid white/black)
```

### 5.2 Blend Modes

| Layer | Blend Mode | Opacity |
|-------|------------|---------|
| Noise Overlay | Normal | 5% |
| Fluid 'L' | Normal | 100% |
| Glass Card | Normal | 25% (light), 30% (dark) |
| Background | Normal | 100% |

---

## 6. iOS Icon Size Variants

### 6.1 Required Sizes

All sizes must be generated from the 1024×1024 master:

| Size | Scale | Platform | Usage | Export Name |
|------|-------|----------|-------|-------------|
| 1024×1024 | 1x | iOS Universal | App Store | `app-icon-1024.png` |
| 512×512 | 1x | macOS | Mac App Store | `app-icon-512.png` |
| 256×256 | 1x | macOS | Retina Display | `app-icon-256.png` |
| 128×128 | 1x | macOS | Standard Display | `app-icon-128.png` |
| 64×64 | 2x | iOS Universal | Spotlight (Retina) | `app-icon-32@2x.png` |
| 60×60 | 2x | iPhone | App (Retina) | `app-icon-60@2x.png` |
| 60×60 | 3x | iPhone | App (Retina HD) | `app-icon-60@3x.png` |
| 40×40 | 2x | iPad | App (Retina) | `app-icon-40@2x.png` |
| 40×40 | 3x | iPad Pro | App (Retina HD) | `app-icon-40@3x.png` |
| 29×29 | 2x | iOS Universal | Settings (Retina) | `app-icon-29@2x.png` |
| 29×29 | 3x | iOS Universal | Settings (Retina HD) | `app-icon-29@3x.png` |
| 20×20 | 2x | iOS Universal | Notifications (Retina) | `app-icon-20@2x.png` |
| 20×20 | 3x | iOS Universal | Notifications (Retina HD) | `app-icon-20@3x.png` |
| 16×16 | 1x | macOS | Info.plist | `app-icon-16.png` |

### 6.2 Export Quality

| Property | Value |
|----------|-------|
| **Format** | PNG (lossless) |
| **Interlacing** | None (progressive OK) |
| **Compression** | None (or pngcrush optimization) |
| **Color Profile** | sRGB |
| **Metadata** | None (strip EXIF, etc.) |

---

## 7. Accessibility & Contrast

### 7.1 Contrast Ratios

| Element | Light Mode | Dark Mode | WCAG AA | WCAG AAA |
|---------|-----------|-----------|---------|----------|
| Glass card on background | 1.05:1 | 1.10:1 | N/A | N/A |
| Gradient 'L' on glass | 3.2:1 | 4.1:1 | ✅ Pass | ❌ Fail |

**Note**: Glass effect is decorative, not content-bearing, so lower contrast is acceptable per WCAG.

### 7.2 Minimum Legibility

| Size | Minimum Feature Size |
|------|---------------------|
| 16×16 | 2 pixels |
| 20×20 | 2.5 pixels |
| 29×29 | 3.5 pixels |
| 60×60 | 7 pixels |
| 1024×1024 | 120 pixels |

**Rule of thumb**: At any size, the 'L' stroke must be ≥2 pixels wide to remain legible.

---

## 8. Validation Criteria

### 8.1 Visual Validation

✅ **Pass Criteria**:
- Glass morphism effect clearly visible
- Fluid 'L' symbol is centered
- Gradient colors match specification exactly
- Blur radius appears ~40px (not too muddy, not too sharp)
- Noise texture is subtle (not gritty)
- Icon remains recognizable at 16×16

❌ **Fail Criteria**:
- Flat design (no blur/transparency)
- Wrong symbol (jellyfish or other)
- Gradient uses wrong colors
- 'L' not recognizable at small sizes
- Moiré patterns or banding
- Artifacts from compression

### 8.2 Technical Validation

✅ **Pass Criteria**:
- PNG format, no alpha channel (solid background)
- Dimensions exactly 1024×1024
- File size < 500 KB
- sRGB color profile
- No compression artifacts

❌ **Fail Criteria**:
- JPEG format (lossy compression)
- Alpha channel (App Store rejects)
- Wrong dimensions (e.g., 1020×1020)
- File size > 500 KB
- Wrong color profile (e.g., Adobe RGB)

### 8.3 Integration Validation

✅ **Pass Criteria**:
- Icon appears on iOS home screen
- Icon visible in Settings app
- Icon visible in Spotlight search
- No warnings in Xcode
- Contents.json correctly references all sizes

❌ **Fail Criteria**:
- Default Xcode icon shows
- Missing icon at any size
- Xcode warnings about missing references
- Icon not appearing after clean build

---

## 9. File Naming Conventions

### 9.1 Primary Files

| File | Description |
|------|-------------|
| `app-icon.png` | 1024×1024, light mode |
| `app-icon-dark.png` | 1024×1024, dark mode |

### 9.2 iOS Variants

Pattern: `app-icon-{size}@{scale}x.png`

- Examples:
  - `app-icon-60@2x.png` (120×120 pixels)
  - `app-icon-60@3x.png` (180×180 pixels)
  - `app-icon-29@2x.png` (58×58 pixels)

### 9.3 Source Files

| File | Format | Purpose |
|------|--------|---------|
| `app-icon.fig` | Figma | Editable design file |
| `app-icon.sketch` | Sketch | Editable design file |
| `app-icon.ai` | Illustrator | Editable design file |
| `app-icon.svg` | SVG | Vector source (optional) |

---

## 10. Common Tolerances

While exact values are preferred, some tolerances are acceptable:

| Property | Exact Value | Acceptable Range | Notes |
|----------|-------------|------------------|-------|
| Glass card size | 819px | 817-821px | ±2px |
| Corner radius | 184px | 179-189px | ±5px |
| Blur radius | 40px | 35-45px | ±5px |
| Glass opacity | 25% | 23-27% | ±2% |
| Border opacity | 40% | 35-45% | ±5% |
| Noise opacity | 5% | 4-6% | ±1% |

**Critical Values (No Tolerance)**:
- Canvas size: Must be exactly 1024×1024
- Gradient colors: Must use exact hex codes
- File format: Must be PNG

---

## 11. Comparison Matrix

### 11.1 Before vs After

| Aspect | Old Icon (Jellyfish) | New Icon (Glass 'L') |
|--------|---------------------|----------------------|
| **Style** | Flat | Glass morphism |
| **Symbol** | Jellyfish | Fluid 'L' |
| **Depth** | None | Multi-layered |
| **Blur** | None | 40px Gaussian |
| **Transparency** | None | 25-30% |
| **Gradient** | None | Indigo→pink→violet |
| **Noise** | None | 5% texture |
| **Glass Effect** | 0/10 | 9/10 |
| **Brand Alignment** | 2/10 | 10/10 |

### 11.2 Competitor Comparison

| App | Icon Style | Glass Effect | Branding |
|-----|------------|--------------|----------|
| **LexiconFlow** | Glass morphism 'L' | ✅ 9/10 | ✅ Premium |
| **Anki** | Flat elephant | ❌ 0/10 | ⚠️ Dated |
| **Quizlet** | Flat 'Q' | ❌ 0/10 | ⚠️ Generic |

---

## 12. Quality Assurance Checklist

### Design QA

- [ ] Canvas is exactly 1024×1024
- [ ] Background is solid #FFFFFF (light) or #000000 (dark)
- [ ] Glass card is 819×819, centered
- [ ] Glass card has 184px corner radius
- [ ] Glass card has 40px Gaussian blur
- [ ] Glass card opacity is 25% (light) or 30% (dark)
- [ ] Border is 2px, 40% (light) or 50% (dark) opacity
- [ ] Fluid 'L' is centered
- [ ] Gradient uses exact hex codes: #6366F1→#EC4899→#8B5CF6
- [ ] Noise overlay is 5% opacity

### Export QA

- [ ] All 16 iOS sizes generated
- [ ] Files are PNG format
- [ ] No alpha channel (solid backgrounds)
- [ ] File sizes < 500 KB each
- [ ] sRGB color profile
- [ ] Filenames follow Apple HIG convention

### Integration QA

- [ ] Icons replace flat jellyfish in asset catalog
- [ ] Contents.json updated with all filenames
- [ ] No Xcode warnings or errors
- [ ] Icon appears on home screen
- [ ] Icon visible in Settings app
- [ ] Icon works in light mode
- [ ] Icon works in dark mode
- [ ] 'L' recognizable at smallest size (16×16)

---

## 13. Reference Implementations

### 13.1 Figma Component Properties

```json
{
  "name": "App Icon / Light Mode",
  "width": 1024,
  "height": 1024,
  "children": [
    {
      "name": "Background",
      "type": "RECTANGLE",
      "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1}}]
    },
    {
      "name": "Glass Card",
      "type": "RECTANGLE",
      "width": 819,
      "height": 819,
      "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1}, "opacity": 0.25}],
      "strokes": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1}, "opacity": 0.4}],
      "strokeWeight": 2,
      "cornerRadii": [184, 184, 184, 184],
      "effects": [{"type": "LAYER_BLUR", "radius": 40}]
    },
    {
      "name": "Fluid L",
      "type": "VECTOR",
      "fills": [{
        "type": "GRADIENT_LINEAR",
        "gradientStops": [
          {"position": 0, "color": {"r": 0.388, "g": 0.4, "b": 0.945}},
          {"position": 0.5, "color": {"r": 0.925, "g": 0.282, "b": 0.6}},
          {"position": 1, "color": {"r": 0.545, "g": 0.361, "b": 0.965}}
        ]
      }]
    },
    {
      "name": "Noise Overlay",
      "type": "RECTANGLE",
      "fills": [{"type": "SOLID", "opacity": 0.05}],
      "blendMode": "NORMAL"
    }
  ]
}
```

---

## Appendix A: Color Conversion Table

| Color Name | Hex | RGB (Decimal) | RGB (Percentage) | HSL |
|-----------|-----|---------------|------------------|-----|
| **Indigo 500** | #6366F1 | rgb(99, 102, 241) | rgb(38.8%, 40%, 94.5%) | hsl(239, 84%, 67%) |
| **Pink 500** | #EC4899 | rgb(236, 72, 153) | rgb(92.5%, 28.2%, 60%) | hsl(330, 81%, 60%) |
| **Violet 500** | #8B5CF6 | rgb(139, 92, 246) | rgb(54.5%, 36.1%, 96.5%) | hsl(258, 90%, 66%) |
| **White** | #FFFFFF | rgb(255, 255, 255) | rgb(100%, 100%, 100%) | hsl(0, 0%, 100%) |
| **Black** | #000000 | rgb(0, 0, 0) | rgb(0%, 0%, 0%) | hsl(0, 0%, 0%) |

---

## Appendix B: Quick Validation Commands

```bash
# Check file dimensions
file app-icon.png
# Output: app-icon.png: PNG image data, 1024 x 1024, 8-bit/color RGB

# Check file size
ls -lh app-icon.png
# Output: -rw-r--r-- 1 user staff 168K Jan 5 23:26 app-icon.png

# Check color profile (requires ImageMagick)
identify -verbose app-icon.png | grep "Colorspace"
# Output: Colorspace: sRGB

# Validate PNG integrity
pngcheck app-icon.png
# Output: OK: app-icon.png (1024x1024, 8-bit RGB, non-interlaced)

# Compare with specification
python3 scripts/validate_app_store_assets.py --icon app-icon.png
```

---

**Document Control**

- **Author**: Design & Engineering Team
- **Status**: Final specification
- **Review Frequency**: Each icon iteration
- **Related Documents**:
  - [app-icon-design-concept.md](./app-icon-design-concept.md)
  - [app-icon-visual-reference.md](./app-icon-visual-reference.md)
  - [app-icon-implementation-guide.md](./app-icon-implementation-guide.md)
