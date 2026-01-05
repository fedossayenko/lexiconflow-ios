# App Icon Quick Reference

**Version**: 1.0
**Last Updated**: 2026-01-06
**Purpose**: Quick reference for app icon design specifications

---

## One-Line Summary

Create a glass morphism app icon with a fluid 'L' symbol (gradient #6366F1→#EC4899→#8B5CF6) on a frosted glass card (819×819, 40px blur, 25% opacity) with 5% noise texture.

---

## Key Specs at a Glance

```
┌────────────────────────────────────────────────────┐
│           LEXICONFLOW APP ICON - KEY SPECS         │
├────────────────────────────────────────────────────┤
│ Canvas:         1024×1024                           │
│ Glass Card:     819×819 (80% of canvas)            │
│ Corner Radius:  184px (22.5% of card)              │
│ Symbol:         Fluid 'L'                          │
│ Gradient:       #6366F1 → #EC4899 → #8B5CF6        │
│ Blur:           40px Gaussian                       │
│ Opacity:        25% (light), 30% (dark)            │
│ Border:         2px, 40% opacity                    │
│ Noise:          5% grayscale                        │
└────────────────────────────────────────────────────┘
```

---

## Color Palette

### Gradient Colors

```
Indigo → Pink → Violet
  #6366F1 → #EC4899 → #8B5CF6
```

### Quick CSS Reference

```css
/* Gradient for 'L' symbol */
background: linear-gradient(45deg, #6366F1 0%, #EC4899 50%, #8B5CF6 100%);

/* Glass card (light mode) */
background: rgba(255, 255, 255, 0.25);
backdrop-filter: blur(40px);
border: 2px solid rgba(255, 255, 255, 0.4);

/* Glass card (dark mode) */
background: rgba(255, 255, 255, 0.30);
backdrop-filter: blur(40px);
border: 2px solid rgba(255, 255, 255, 0.5);
```

---

## Layer Order (Top to Bottom)

```
1. Noise Overlay (5% opacity)
2. Fluid 'L' Symbol (gradient)
3. Glass Card (25% opacity, 40px blur)
4. Background (solid #FFFFFF or #000000)
```

---

## Size Checklist

```
Required iOS Sizes (from 1024×1024 master):

✓ 1024×1024  (App Store)
✓ 512×512    (Mac App Store)
✓ 256×256    (macOS Retina)
✓ 128×128    (macOS 1x)
✓ 128×128    (Spotlight @2x)
✓ 120×120    (iPhone @3x)
✓ 120×120    (iPad Pro @3x)
✓ 80×80      (iPad @2x)
✓ 60×60      (iPhone @2x)
✓ 87×87      (Settings @3x)
✓ 58×58      (Settings @2x)
✓ 60×60      (Notifications @3x)
✓ 40×40      (Notifications @2x)
✓ 16×16      (Info.plist)

Total: 14 sizes (28 including dark mode)
```

---

## Common Commands

### Generate All Sizes (Figma Plugin)

```
1. Install: "App Icon Generator" plugin
2. Select 1024×1024 frame
3. Run: Plugins → App Icon Generator
4. Choose: iOS platform
5. Export to: Asset catalog
```

### Generate All Sizes (Python Script)

```bash
python3 scripts/generate-icon-variants.py \
  --input app-icon.png \
  --output LexiconFlow/LexiconFlow/Assets.xcassets/AppIcon.appiconset/
```

### Validate Icon

```bash
# Check dimensions
file app-icon.png
# Output: PNG image data, 1024 x 1024

# Check file size
ls -lh app-icon.png
# Should be < 500 KB

# Run validation script
python3 scripts/validate_app_store_assets.py --icon app-icon.png
```

---

## Design Principles

### ✅ DO

- Use glass morphism (blur + transparency)
- Keep symbol simple (fluid 'L' only)
- Test at 16×16 size
- Use exact gradient colors
- Add noise texture (5%)
- Round corners (184px radius)

### ❌ DON'T

- Use jellyfish or any symbol other than 'L'
- Skip blur effect (makes it flat)
- Use more than 3 gradient colors
- Make noise texture > 10% (too gritty)
- Forget to test smallest size
- Use JPEG format (must be PNG)

---

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Icon looks flat | No blur | Add 40px Gaussian blur to glass card |
| 'L' not readable at small size | Stroke too thin | Increase stroke width to 120px (base) |
| Gradient looks muddy | Too many colors | Use exactly 3 colors (indigo→pink→violet) |
| Glass looks plastic | No noise texture | Add 5% noise overlay |
| Files rejected by App Store | Alpha channel | Remove transparency, use solid background |

---

## File Naming

### Light Mode

```
app-icon-1024.png
app-icon-60@2x.png
app-icon-29@3x.png
...
```

### Dark Mode

```
app-icon-1024-dark.png
app-icon-60@2x-dark.png
app-icon-29@3x-dark.png
...
```

---

## Testing Checklist

```
Before committing:

□ Icon appears on home screen
□ Icon visible in Settings app
□ Icon visible in Spotlight search
□ 'L' recognizable at 16×16
□ Works in light mode
□ Works in dark mode
□ Works with "Reduce Transparency"
□ No Xcode warnings
□ All 14 sizes present
□ File sizes < 500 KB each
```

---

## Export Settings (Figma)

```
Format: PNG
Scale: 1x (for each size)
Suffix: None (we'll add @2x, @3x manually)
```

---

## Tolerances

| Spec | Value | Acceptable Range |
|------|-------|------------------|
| Glass card size | 819px | 817-821px (±2px) |
| Corner radius | 184px | 179-189px (±5px) |
| Blur radius | 40px | 35-45px (±5px) |
| Glass opacity | 25% | 23-27% (±2%) |
| Noise opacity | 5% | 4-6% (±1%) |

**NO TOLERANCE**:
- Canvas size: Must be exactly 1024×1024
- Gradient colors: Must use exact hex codes
- Symbol: Must be 'L', not jellyfish

---

## Related Documents

📄 **Full Design Concept**: [app-icon-design-concept.md](./app-icon-design-concept.md)
📄 **Visual Reference**: [app-icon-visual-reference.md](./app-icon-visual-reference.md)
📄 **Implementation Guide**: [app-icon-implementation-guide.md](./app-icon-implementation-guide.md)
📄 **Technical Spec**: [app-icon-design-specification.md](./app-icon-design-specification.md)
📄 **Variants Guide**: [app-icon-variants-guide.md](./app-icon-variants-guide.md)
📄 **Designer Brief**: [app-icon-designer-brief.md](./app-icon-designer-brief.md)

---

## Quick Contact

- **Design Questions**: See [app-icon-design-concept.md](./app-icon-design-concept.md)
- **Implementation Help**: See [app-icon-implementation-guide.md](./app-icon-implementation-guide.md)
- **Technical Specs**: See [app-icon-design-specification.md](./app-icon-design-specification.md)

---

**Print-Friendly Version**

This document is designed to be printed and kept at your desk for quick reference while designing.

```
┌─────────────────────────────────┐
│  LEXICONFLOW                    │
│  App Icon Quick Reference       │
│                                 │
│  Symbol: Fluid 'L'              │
│  Style: Glass morphism          │
│  Canvas: 1024×1024              │
│  Card: 819×819, 40px blur       │
│  Colors: #6366F1 → #EC4899      │
│          → #8B5CF6              │
│  Opacity: 25% (light), 30% (dark)│
│  Border: 2px, 40% opacity       │
│  Noise: 5%                      │
│                                 │
⚠️  NO JELLYFISH!                 │
└─────────────────────────────────┘
```

---

**Version History**

- v1.0 (2026-01-06): Initial version

---

**End of Quick Reference**
