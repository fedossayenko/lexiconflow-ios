# App Icon Visual Reference

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Owner**: LexiconFlow Design Team

---

## Color Palette

### Primary Gradient

```
┌─────────────────────────────────────────────────────┐
│  Fluid 'L' Symbol Gradient (45° angle)              │
│                                                     │
│  Start:  #6366F1  │  Indigo 500  │  RGB(99,102,241) │
│  Middle: #EC4899  │  Pink 500    │  RGB(236,72,153) │
│  End:    #8B5CF6  │  Violet 500  │  RGB(139,92,246) │
│                                                     │
│  Gradient Stops:                                    │
│    0%   → #6366F1                                  │
│    50%  → #EC4899                                  │
│    100% → #8B5CF6                                  │
└─────────────────────────────────────────────────────┘
```

### Glass Card Colors

| Mode | Background | Glass Fill | Border |
|------|-----------|------------|--------|
| **Light** | `#FFFFFF` (100%) | `#FFFFFF` (25% opacity) | `#FFFFFF` (40% opacity) |
| **Dark** | `#000000` (100%) | `#FFFFFF` (30% opacity) | `#FFFFFF` (50% opacity) |

### Noise Texture

- **Color**: Monochromatic grayscale
- **Opacity**: 5%
- **Pattern**: Perlin noise or Gaussian noise
- **Resolution**: 512×512px (tiled)

---

## Dimensions & Spacing

### Icon Layout (1024×1024 canvas)

```
┌─────────────────────────────────────────────────────┐
│                 1024px                              │
│            ┌───────────────────┐                    │
│            │    ┌─────────┐   │                    │
│            │    │         │   │                    │
│   1024px   │    │   819px │   │   ← Glass Card     │
│            │    │         │   │     (80% canvas)   │
│            │    │   ┌─┐   │   │                    │
│            │    │   │L│  │   │   ← Fluid 'L'       │
│            │    │   └─┘   │   │     (centered)     │
│            │    └─────────┘   │                    │
│            │       │   │                            │
│            └───────┴───┴───────────────────────────┘
│                     │
│              Center: (512, 512)
└─────────────────────────────────────────────────────┘
```

### Glass Card (819×819)

| Property | Value | Calculation |
|----------|-------|-------------|
| **Width/Height** | 819px | 1024 × 0.80 |
| **Corner Radius** | 184px | 819 × 0.225 |
| **Center X/Y** | 512px | (1024 - 819) / 2 + 819/2 |
| **Border Width** | 2px | Fixed |
| **Blur Radius** | 40px | Fixed |

### Fluid 'L' Symbol

| Property | Value | Notes |
|----------|-------|-------|
| **Height** | ~500px | Scaled to fit within card |
| **Stroke Width** | 120px | At thickest point (downstroke) |
| **Crossbar Width** | 60px | At thinnest point |
| **Center X/Y** | 512px | Centered in glass card |
| **Padding** | 159px | (819 - 500) / 2 |

---

## Typography: The 'L' Symbol

### Calligraphic Properties

```
Vertical Stroke (Downstroke)
├─ Thickness: 120px (base) → 80px (top, tapered)
├─ Curve: Slight 5° inward bend
└─ Style: Brush-like, slight pressure variation

Horizontal Stroke (Crossbar)
├─ Thickness: 60px (uniform)
├─ Position: 30% from top
├─ Length: 60% of vertical stroke height
└─ Connection: Smooth, calligraphic join
```

### SVG Path Construction

If creating manually as SVG:

```xml
<svg viewBox="0 0 819 819" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="fluidL" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6366F1;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#EC4899;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#8B5CF6;stop-opacity:1" />
    </linearGradient>
  </defs>

  <!-- Fluid 'L' path (simplified) -->
  <path d="M 330 159
           C 330 159, 350 159, 370 159
           C 390 159, 410 180, 410 200
           L 410 600
           C 410 620, 400 640, 380 640
           L 200 640
           C 180 640, 170 620, 170 600
           C 170 580, 180 560, 200 560
           L 330 560
           L 330 200
           C 330 180, 340 170, 350 170
           Z"
        fill="url(#fluidL)"
        stroke="none" />
</svg>
```

---

## Layer Stack Visual

```
┌──────────────────────────────────────────────────────┐
│ Layer 4: Noise Overlay (5% opacity)                  │
│ ──────────────────────────────────────────────────── │
│ Layer 3: Fluid 'L' Symbol (Gradient)                 │
│ ┌─────────────────────────────────────────────────┐  │
│ │                                                 │  │
│ │            ╭──────╮                            │  │
│ │            │      │                            │  │
│ │            │      ╰────────╮                   │  │
│ │                     ╰───────╯                   │  │
│ │                                                 │  │
│ └─────────────────────────────────────────────────┘  │
│ Layer 2: Glass Card (25% opacity, 40px blur)          │
│ ┌─────────────────────────────────────────────────┐  │
│ │                                                 │  │
│ │                                                 │  │
│ │           (frosted glass effect)                │  │
│ │                                                 │  │
│ │                                                 │  │
│ └─────────────────────────────────────────────────┘  │
│ Layer 1: Solid Background (#FFFFFF)                   │
│ ──────────────────────────────────────────────────── │
└──────────────────────────────────────────────────────┘
```

---

## Icon Size Reference Table

### iOS Required Sizes

| Size | Scale | ID | Usage | Export Name |
|------|-------|-------|-------|-------------|
| 1024×1024 | 1x | `app-icon-1024` | App Store | `app-icon-1024.png` |
| 256×256 | 2x | `app-icon-128@2x` | Mac App Store | `app-icon-128@2x.png` |
| 128×128 | 1x | `app-icon-128` | Mac App Store | `app-icon-128.png` |
| 64×64 | 2x | `app-icon-32@2x` | Spotlight | `app-icon-32@2x.png` |
| 60×60 | 2x | `app-icon-60@2x` | iPhone (Retina) | `app-icon-60@2x.png` |
| 60×60 | 3x | `app-icon-60@3x` | iPhone (Retina HD) | `app-icon-60@3x.png` |
| 40×40 | 2x | `app-icon-40@2x` | iPad (Retina) | `app-icon-40@2x.png` |
| 40×40 | 3x | `app-icon-40@3x` | iPad Pro (Retina HD) | `app-icon-40@3x.png` |
| 29×29 | 2x | `app-icon-29@2x` | Settings (Retina) | `app-icon-29@2x.png` |
| 29×29 | 3x | `app-icon-29@3x` | Settings (Retina HD) | `app-icon-29@3x.png` |
| 20×20 | 2x | `app-icon-20@2x` | Notifications (Retina) | `app-icon-20@2x.png` |
| 20×20 | 3x | `app-icon-20@3x` | Notifications (Retina HD) | `app-icon-20@3x.png` |
| 16×16 | 1x | `app-icon-16` | Info.plist | `app-icon-16.png` |

---

## Figma Layer Properties

### Glass Card Rectangle

```json
{
  "type": "RECTANGLE",
  "width": 819,
  "height": 819,
  "x": 102.5,
  "y": 102.5,
  "rotation": 0,
  "fills": [
    {
      "type": "SOLID",
      "color": { "r": 1, "g": 1, "b": 1 },
      "opacity": 0.25
    }
  ],
  "strokes": [
    {
      "type": "SOLID",
      "color": { "r": 1, "g": 1, "b": 1 },
      "opacity": 0.4
    }
  ],
  "strokeWeight": 2,
  "effects": [
    {
      "type": "LAYER_BLUR",
      "radius": 40,
      "visible": true
    }
  ],
  "cornerRadii": [184, 184, 184, 184]
}
```

### Fluid 'L' Vector

```json
{
  "type": "VECTOR",
  "fills": [
    {
      "type": "GRADIENT_LINEAR",
      "gradientHandlePositions": [
        { "x": 0, "y": 0.5 },
        { "x": 1, "y": 0.5 }
      ],
      "gradientStops": [
        {
          "position": 0,
          "color": { "r": 0.388, "g": 0.4, "b": 0.945 }
        },
        {
          "position": 0.5,
          "color": { "r": 0.925, "g": 0.282, "b": 0.6 }
        },
        {
          "position": 1,
          "color": { "r": 0.545, "g": 0.361, "b": 0.965 }
        }
      ]
    }
  ],
  "strokeWeight": 0,
  "strokeAlign": "CENTER"
}
```

---

## Comparisons: Before vs After

### Current Icon (Flat Jellyfish)

```
┌──────────────────┐
│   🪼 JELLYFISH   │  ← Flat design
│                  │  ‣ No depth
│   Flat colors    │  ‣ No blur
│   No transparency│  ‣ No gradient
│   No 'L' symbol  │  ‣ Wrong symbol
└──────────────────┘
Rating: 2/10 for glass morphism
```

### New Icon (Glass Morphism)

```
┌──────────────────┐
│    ┌─────────┐   │  ← Frosted glass
│    │  ╭───╮  │   │  ‣ 40px blur
│    │  │ L │  │   │  ‣ 25% opacity
│    │  ╰───╯  │   │  ‣ Gradient
│    │         │   │  ‣ Noise texture
│    └─────────┘   │  ‣ Fluid 'L'
└──────────────────┘
Rating: 9/10 for glass morphism
```

---

## Quality Checklist

### Design Validation

- [ ] Gradient uses exact hex codes: #6366F1, #EC4899, #8B5CF6
- [ ] Glass card is exactly 819×819px (80% of 1024×1024)
- [ ] Corner radius is 184px (22.5% of card width)
- [ ] Blur radius is 40px Gaussian blur
- [ ] Border is 2px with 40% opacity (light) or 50% (dark)
- [ ] Noise texture is 5% opacity, not more
- [ ] Fluid 'L' is perfectly centered
- [ ] No moiré patterns at small sizes

### Export Validation

- [ ] All sizes exported as PNG (no alpha channel for App Store)
- [ ] Files named correctly per Apple HIG
- [ ] No artifacts or banding in gradients
- [ ] File sizes under 500KB per icon
- [ ] Color profile: sRGB

---

## Visual Mockup Template

### Light Mode Preview

```
Background: #FFFFFF (system white)
┌──────────────────────────────────┐
│                                  │
│                                  │
│        ┌─────────────────┐       │
│        │                 │       │
│        │    ╭───╮        │       │
│        │    │ L │        │       │
│        │    ╰───╯        │       │
│        │                 │       │
│        └─────────────────┘       │
│                                  │
└──────────────────────────────────┘
```

### Dark Mode Preview

```
Background: #000000 (system black)
┌──────────────────────────────────┐
│                                  │
│                                  │
│        ┌─────────────────┐       │
│        │                 │       │
│        │    ╭───╮        │       │
│        │    │ L │        │       │
│        │    ╰───╯        │       │
│        │                 │       │
│        └─────────────────┘       │
│                                  │
└──────────────────────────────────┘
```

---

## Asset Checklist

### Files to Create

- [ ] `app-icon-1024.png` - App Store (light)
- [ ] `app-icon-1024-dark.png` - App Store (dark)
- [ ] `app-icon-512.png` - Mac App Store
- [ ] `app-icon-256.png` - macOS (Retina)
- [ ] `app-icon-128.png` - macOS (1x)
- [ ] `app-icon-64@2x.png` - Spotlight
- [ ] `app-icon-60@2x.png` - iPhone (Retina)
- [ ] `app-icon-60@3x.png` - iPhone (Retina HD)
- [ ] `app-icon-40@2x.png` - iPad (Retina)
- [ ] `app-icon-40@3x.png` - iPad Pro (Retina HD)
- [ ] `app-icon-29@2x.png` - Settings (Retina)
- [ ] `app-icon-29@3x.png` - Settings (Retina HD)
- [ ] `app-icon-20@2x.png` - Notifications (Retina)
- [ ] `app-icon-20@3x.png` - Notifications (Retina HD)
- [ ] `app-icon-16.png` - Info.plist

**Total**: 16 icon assets (including dark mode variant)

---

## Next Steps

1. ✅ Visual reference documented
2. ⏳ Create designer brief
3. ⏳ Design icon in Figma
4. ⏳ Export all iOS sizes
5. ⏳ Test in iOS Simulator

---

**Document Control**

- **Author**: Design Team
- **Status**: Approved for use
- **Source**: [app-icon-design-concept.md](./app-icon-design-concept.md)
