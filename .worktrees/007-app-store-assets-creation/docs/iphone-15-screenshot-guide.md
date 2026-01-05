# iPhone 15 Screenshot Guide

## Device Specifications

**iPhone 15**
- Screen Size: 6.1" (diagonal)
- Resolution: 1290x2796 pixels
- Status Bar: 54px (Dynamic Island)
- Home Indicator: 18px
- Safe Area Top: 54px
- Safe Area Bottom: 34px
- Screenshot Resolution: 1290x2796
- Caption Height: 100px
- Caption Font Size: 26pt

## Simulator Setup

1. **Open Xcode**
2. **Select Simulator**: iPhone 15
3. **Configure Settings**:
   - Display Mode: Light
   - Reduce Transparency: OFF
   - Time: 9:41 AM
   - Battery: 100%
   - Do Not Disturb: ON
   - Dynamic Island: Ensure visible in screenshots

## Test Data Setup

See `docs/test-data-setup-guide.md`.

**Quick Setup**:
- 3 decks with 10 flashcards each
- 5-8 cards marked as "due"

## Screenshot Capture

Same 6 screens as iPhone SE, but with higher resolution and Dynamic Island.

### Screenshot 1: Welcome
- Save: `screenshots_raw/iphone_15/1_Welcome_1290x2796.png`

### Screenshot 2: FSRS Algorithm
- Save: `screenshots_raw/iphone_15/2_FSRS_Algorithm_1290x2796.png`

### Screenshot 3: Deck Management
- Save: `screenshots_raw/iphone_15/3_Deck_Management_1290x2796.png`

### Screenshot 4: Liquid Glass Study (HERO)
- Save: `screenshots_raw/iphone_15/4_Liquid_Glass_Study_1290x2796.png`

### Screenshot 5: Smart Rating
- Save: `screenshots_raw/iphone_15/5_Smart_Rating_1290x2796.png`

### Screenshot 6: Study Modes
- Save: `screenshots_raw/iphone_15/6_Study_Modes_1290x2796.png`

## Post-Processing

```bash
python3 scripts/process_screenshots.py --device iphone_15
```

## Device-Specific Considerations

- **Dynamic Island**: Ensure it's visible but not distracting
- **Larger Screen**: Can show more content than iPhone SE
- **Caption**: Taller (100px) with larger font (26pt)

## Quality Checklist

- [ ] Resolution: 1290x2796
- [ ] Dynamic Island visible
- [ ] Content properly scaled for 6.1" display
- [ ] Glass effects clearly visible
- [ ] Captions legible

## Time Estimate

- Capture: ~30 minutes
- Post-processing: ~15 minutes
- **Total**: ~45 minutes

---

**Related**: `docs/screenshots-plan.md`
