# App Icon Quick Reference

## TL;DR - Fast Access

**Recommendation**: Use **universal icon** (iOS 11+). Just create 1024x1024 and you're done.

---

## Canvas Specs

| Property | Value |
|----------|-------|
| Size | 1024x1024px |
| Format | PNG-24 |
| Color | sRGB |
| Max file size | < 500KB |

---

## Colors

```
Gradient (135°): #6366F1 → #EC4899 → #8B5CF6
Letter "L": #FFFFFF
Glass Card: #FFFFFF @ 25% opacity
Border: 2px #FFFFFF @ 40% opacity
Shadow: rgba(0,0,0,0.15) for card, rgba(0,0,0,0.25) for "L"
```

---

## Layout

```
Glass Card: 819x819px, centered (X: 102.5, Y: 102.5)
Corner Radius: 180px
Blur: 40px
Letter "L": ~700px tall, centered
```

---

## Export

```
Format: PNG
Settings: sRGB, 32-bit, opaque background
File name: AppIcon-1024.png
```

---

## Xcode Integration

1. Open `Assets.xcassets`
2. Select `AppIcon`
3. Drag `AppIcon-1024.png` to 1024x1024 slot
4. Done! iOS generates all other sizes.

---

## If Small Icons Look Bad

Create explicit versions for 16x16, 29x29:
- Thicken "L" stroke by 20-30%
- Reduce blur to 20-25px
- Increase opacity to 35-40%

---

## Tools

- **Figma** (⭐️ Free, recommended): https://www.figma.com
- **Sketch** ($99/year): https://www.sketch.com
- **Adobe CC** ($54/month): https://www.adobe.com

---

## Generation Scripts

```bash
# macOS built-in (simplest)
sips -z 29 29 AppIcon-1024.png --out AppIcon-29.png

# Python (cross-platform)
python3 scripts/generate-icon-variants.py AppIcon-1024.png

# Shell script (macOS)
./scripts/generate-icon-variants.sh
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Glass not visible | Increase blur to 50-60px or opacity to 30% |
| "L" off-center | Use alignment tools |
| Colors wrong | Check color profile is sRGB |
| File too large | Optimize with ImageOptim or TinyPNG |
| Transparency | Add background fill, flatten before export |

---

## Related Docs

- Full specs: `app-icon-design-specification.md`
- How-to: `app-icon-implementation-guide.md`
- Variants: `app-icon-variants-guide.md`

---

**Version**: 1.0 | **Updated**: 2026-01-06
