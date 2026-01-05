# iPhone 15 Pro Max Screenshot Guide

## Device Specifications

**iPhone 15 Pro Max**
- Screen Size: 6.7" (diagonal) - largest iPhone display
- Resolution: 1320x2868 pixels
- Status Bar: 59px (Dynamic Island, larger)
- Home Indicator: 18px
- Safe Area Top: 59px
- Safe Area Bottom: 34px
- Screenshot Resolution: 1320x2868
- Caption Height: 110px
- Caption Font Size: 28pt

## Why iPhone 15 Pro Max?

**Best for showcasing app**:
- Largest display (6.7" vs 6.1" on iPhone 15)
- More screen real estate for glass morphism effects
- Can show 4-5 decks vs 3-4 on smaller devices
- Premium feel conveys app quality

**Marketing Recommendation**: Use iPhone 15 Pro Max screenshots as "hero" screenshots in App Store preview (first 2-3 screenshots).

## Simulator Setup

Same as iPhone 15, but select **iPhone 15 Pro Max** simulator.

## Screenshot Capture

Same workflow, but save to `screenshots_raw/iphone_15_pro_max/` with resolution 1320x2868.

### Enhanced Content Setup

- **Decks**: Show 4-5 decks (more space)
- **Glass Effects**: More prominent on larger canvas
- **Typography**: Larger, more readable

## Post-Processing

```bash
python3 scripts/process_screenshots.py --device iphone_15_pro_max
```

## Device-Specific Advantages

1. **More Screen Real Estate**: 30px wider, 72px taller than iPhone 15
2. **Prominent Glass Morphism**: Blur effects more dramatic
3. **Better Content Display**: 4-5 decks visible
4. **Enhanced Readability**: Larger text and UI elements
5. **Premium Feel**: Titanium frame conveys quality

## Quality Checklist

- [ ] Resolution: 1320x2868
- [ ] Content uses full width effectively
- [ ] 4-5 decks visible (not just 3-4)
- [ ] Glass effects prominent
- [ ] Large Dynamic Island visible
- [ ] Captions sized appropriately (110px, 28pt)

## Time Estimate

- Capture: ~30 minutes
- Post-processing: ~15 minutes
- **Total**: ~45 minutes

---

**Related**: `docs/screenshots-plan.md`
