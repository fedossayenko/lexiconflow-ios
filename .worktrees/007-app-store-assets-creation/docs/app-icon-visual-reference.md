# App Icon Visual Reference

## Visual Mockup: Annotated

This document provides an annotated visual reference for the Lexicon Flow app icon design. Use this as a guide when creating the actual icon in a design tool.

### Overall Layout (1024x1024 canvas)

```
┌─────────────────────────────────────────────────────────────┐
│                        Background                           │
│                   Gradient 135° diagonal                     │
│              #6366F1 → #EC4899 → #8B5CF6                    │
│                                                             │
│        ┌───────────────────────────────────────┐            │
│        │                                       │            │
│        │         Glass Card (819x819)          │            │
│        │  ┌─────────────────────────────┐      │            │
│        │  │                             │      │            │
│        │  │                             │      │            │
│        │  │         ┌───┐               │      │            │
│        │  │         │   │               │      │            │
│        │  │         │ L │               │      │            │
│        │  │         │   │               │      │            │
│        │  │         └───┘               │      │            │
│        │  │                             │      │            │
│        │  │                             │      │            │
│        │  └─────────────────────────────┘      │            │
│        │                                       │            │
│        └───────────────────────────────────────┘            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Center Alignment

- **Canvas**: 1024x1024px (center at 512, 512)
- **Glass Card**: 819x819px, centered at (102.5px, 102.5px) offset
- **Letter "L"**: Centered within glass card

## Glass Card Specifications

### Dimensions

```
┌────────────────────────────────────────────────────────┐
│  Card Width: 819px (80% of 1024)                       │
│  Card Height: 819px (80% of 1024)                      │
│  Corner Radius: 180px (22% of width)                   │
│                                                        │
│  ┌────────────────────────────────────────────────┐  │
│  │ ◀────────────── 819px ──────────────────▶       │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │         Border: 2px white               │   │  │
│  │  │         Opacity: 40%                     │   │  │
│  │  │                                         │   │  │
│  │  │         Fill: White                     │   │  │
│  │  │         Opacity: 25%                    │   │  │
│  │  │                                         │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  └─────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### Visual Effects

```
Layer Order (Top to Bottom):

1. Highlight Gradient
   └─ Top edge: rgba(255,255,255,0.3) → transparent
   └─ Height: 100px fade from top

2. Border Stroke
   └─ 2px white, 40% opacity
   └─ Inside edge of card

3. Glass Card Fill
   └─ White, 25% opacity
   └─ 40px Gaussian blur (applied to layer behind)

4. Drop Shadow
   └─ Offset: 0px, 20px
   └─ Blur: 60px
   └─ Color: rgba(0, 0, 0, 0.15)
```

## Letter "L" Specifications

### Dimensions (within 819x819 card)

```
                 Crossbar
┌────────────────────────────────────────┐
│                                        │
│                                        │
│  ┌────────────┐                        │
│  │            │╲                       │
│  │            │ ╲ Stem                 │
│  │            │  ╲  (716px tall)      │
│  │            │   ╲                    │
│  │            │    ╲                   │
│  └────────────┘     ╲                  │
│       (563px)        ╲                 │
│                      ╲                │
│                       ╲               │
│                        ╲              │
│                         └─────────────┘
│
│  Stem: 123px wide
│  Crossbar: 123px thick
└────────────────────────────────────────┘

Measurements from card center (409.5, 409.5):
- L Total Height: 716px
- L Total Width: ~686px
- Stem Thickness: 123px
- Crossbar Thickness: 123px
```

### "L" Shadow Detail

```
     Letter "L" (Solid White #FFFFFF)
     ┌─────────────┐
     │             │
     │             │
     │  ┌──────┐   │◄─ Drop Shadow
     │  │      │   │   Offset: 0px, 4px
     │  │  L   │   │   Blur: 12px
     │  │      │   │   Color: rgba(0,0,0,0.25)
     │  └──────┘   │
     │             │
     └─────────────┘
```

## Background Gradient

### Gradient Flow (135° diagonal)

```
┌─────────────────────────────────────────────────────────┐
│ #6366F1                                      │
│                                                │
│                   #EC4899                      │
│                                                │
│                                       #8B5CF6 │
└─────────────────────────────────────────────────────────┘
     ◀────────── Gradient 135° ──────────────▶

Gradient Stops:
- 0%: #6366F1 (Indigo 500)
- 50%: #EC4899 (Pink 500)
- 100%: #8B5CF6 (Purple 500)
```

## Visual Comparison: Sizes

### Large Size (1024x1024 - App Store)

```
All details visible:
- Glass blur effect: 40px
- Letter shadow: 12px blur
- Border: 2px
- Noise texture: 5%
```

### Medium Size (180x180 - iPhone 3x)

```
Scaled to 17.5% of master:
- Glass blur effect: scales proportionally to ~7px (still visible)
- Letter shadow: scales to ~2px (visible)
- Border: scales to ~0.35px (may appear sub-pixel)
- Noise texture: 5% (still visible)

No manual adjustments needed.
```

### Small Size (60x60 - iPhone App)

```
Scaled to 5.8% of master:
- Glass blur effect: scales to ~2.3px (barely visible)
- Letter shadow: scales to ~0.7px (barely visible)
- Border: scales to ~0.12px (sub-pixel, may disappear)
- Noise texture: 5% (still visible)

Consider slight adjustments for optimal appearance:
- Increase glass card opacity to 30%
- Thicken "L" stroke by 10%
```

### Tiny Size (29x29 - Settings)

```
Scaled to 2.8% of master:
- Glass blur effect: scales to ~1.1px (barely visible)
- Letter shadow: scales to ~0.35px (not visible)
- Border: scales to ~0.06px (not visible)

Recommended adjustments:
- Simplify: Remove blur effect, use solid glass card
- Increase opacity: 35-40% glass card
- Thicken "L" stroke: 20-30% thicker
- Simplified shadow: Single drop shadow, 4px blur
```

### Minimum Size (16x16 - Notifications)

```
Scaled to 1.5% of master:
- Most glass effects lost at this size

Recommended adjustments:
- Solid white "L" on gradient background
- Remove glass card entirely
- Use high-contrast solid colors
- Consider different design: Simple "L" on colored circle
```

## Glass Effect Detail

### Frosted Glass Appearance

```
┌─────────────────────────────────────────────────┐
│  Background Gradient                            │
│  ┌───────────────────────────────────────────┐  │
│  │  Gaussian Blur: 40px                      │  │
│  │  (applied to area behind glass card)      │  │
│  │                                           │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │  Glass Card                         │  │  │
│  │  │  - White fill, 25% opacity          │  │  │
│  │  │  - 2px border, 40% opacity          │  │  │
│  │  │  - Noise texture overlay: 5%        │  │  │
│  │  │  - Inner shadow for depth           │  │  │
│  │  │  - Top highlight gradient           │  │  │
│  │  │                                     │  │  │
│  │  │         ┌───┐                       │  │  │
│  │  │         │ L │                       │  │  │
│  │  │         └───┘                       │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  │                                           │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘

The blur effect is applied to the gradient layer
BEHIND the glass card, creating the frosted appearance.
```

## Layer Stack (For Design Tools)

### Figma Layers

```
App Icon (Frame 1024x1024)
├─ Background Gradient (Rectangle)
│  └─ Fill: Linear Gradient, 135°, #6366F1→#EC4899→#8B5CF6
│  └─ Effect: Layer Blur 40px
│
├─ Glass Card (Rectangle 819x819, Rounded 180px)
│  ├─ Fill: #FFFFFF, Opacity 25%
│  ├─ Stroke: 2px, #FFFFFF, Opacity 40%
│  ├─ Effect: Drop Shadow (0, 20px, 60px, rgba(0,0,0,0.15))
│  ├─ Effect: Inner Shadow (0, 2px, 8px, rgba(255,255,255,0.4))
│  └─ Effect: Background Blur 40px
│
├─ Letter L (Text/Shape)
│  ├─ Fill: #FFFFFF
│  ├─ Font: SF Pro Display Bold (or custom shape)
│  └─ Effect: Drop Shadow (0, 4px, 12px, rgba(0,0,0,0.25))
│
└─ Top Highlight (Rectangle)
   ├─ Fill: Linear Gradient, 90°, rgba(255,255,255,0.3)→transparent
   └─ Mask: Gradient from top 100px height
```

## Color Chips

### Primary Palette

```
┌─────────────────────────────────────────────────────────┐
│ Indigo 500        │  #6366F1  │  rgb(99, 102, 241)      │
├─────────────────────────────────────────────────────────┤
│ Pink 500          │  #EC4899  │  rgb(236, 72, 153)      │
├─────────────────────────────────────────────────────────┤
│ Purple 500        │  #8B5CF6  │  rgb(139, 92, 246)      │
├─────────────────────────────────────────────────────────┤
│ White (100%)      │  #FFFFFF  │  rgb(255, 255, 255)     │
├─────────────────────────────────────────────────────────┤
│ White (25%)       │  #FFFFFF  │  rgb(255, 255, 255, 0.25)
├─────────────────────────────────────────────────────────┤
│ White (40%)       │  #FFFFFF  │  rgb(255, 255, 255, 0.40)
├─────────────────────────────────────────────────────────┤
│ Black Shadow      │  #000000  │  rgb(0, 0, 0, 0.25)      │
└─────────────────────────────────────────────────────────┘
```

### Dark Mode Variant

```
┌─────────────────────────────────────────────────────────┐
│ Indigo 600        │  #4F46E5  │  rgb(79, 70, 229)       │
├─────────────────────────────────────────────────────────┤
│ Pink 600          │  #DB2777  │  rgb(219, 39, 119)      │
├─────────────────────────────────────────────────────────┤
│ Purple 600        │  #7C3AED  │  rgb(124, 58, 237)      │
└─────────────────────────────────────────────────────────┘
```

## Spacing and Alignment

### Golden Ratio Proportions

```
Canvas: 1024x1024
Card: 819x819 (80% of canvas, ~φ ratio)
Margin: 102.5px on all sides

┌─────────────────────────────────────────┐
│ Margin: 102.5px                          │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │     Glass Card (819x819)          │  │
│  │     ┌─────────────────────┐       │  │
│  │     │                     │       │  │
│  │     │        Letter L     │       │  │
│  │     │                     │       │  │
│  │     └─────────────────────┘       │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│  Margin: 102.5px                          │
└─────────────────────────────────────────┘
```

## Export Preview

### File: AppIcon-1024.png

**Settings**:
- Format: PNG-24
- Dimensions: 1024x1024px
- Color Profile: sRGB
- Transparency: No (App Store requires solid background)
- Metadata: None
- Estimated File Size: 300-500KB

**Verification Checklist**:
- ✅ Canvas is exactly 1024x1024px
- ✅ Color profile is sRGB (not Display P3)
- ✅ No transparency channel
- ✅ No compression artifacts
- ✅ "L" is centered
- ✅ Glass card is centered
- ✅ Border radius is 180px
- ✅ Gradient flows from top-left to bottom-right

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Related Documents**:
- `app-icon-design-concept.md` (design philosophy and specifications)
- `app-icon-designer-brief.md` (instructions for designers)
