# iPad Screenshot Guide

## Device Specifications

**iPad Pro 12.9"**
- Screen Size: 12.9" (diagonal)
- Resolution: 2732x2048 pixels (landscape)
- Status Bar: 24px
- Home Indicator: 20px
- Safe Area Top: 24px
- Safe Area Bottom: 20px
- Screenshot Resolution: 2732x2048 (landscape), 2048x2732 (portrait)
- Caption Height: 140px
- Caption Font Size: 36pt

## Orientation Decision

**Primary: Landscape** (2732x2048)
- Natural for study sessions
- Shows more content
- Better for App Store preview

**Secondary: Portrait** (2048x2732)
- Supported but not primary for screenshots

## Simulator Setup

1. **Open Xcode**
2. **Select Simulator**: iPad Pro (12.9-inch) (6th generation)
3. **Orientation**: Command+Left Arrow (landscape)
4. **Configure Settings**:
   - Display Mode: Light
   - Reduce Transparency: OFF
   - Time: 9:41 AM
   - Battery: 100%
   - Do Not Disturb: ON

## Test Data Setup

See `docs/test-data-setup-guide.md`.

**Enhanced Setup for iPad**:
- 4-6 decks (more space)
- 10-15 flashcards per deck
- 8-10 cards marked as "due"

## Screenshot Capture

Same 6 screens as iPhone, but in landscape orientation.

### Screenshot 1: Welcome
- **View**: `OnboardingView`
- **Orientation**: Landscape
- **Save**: `screenshots_raw/ipad/1_Welcome_2732x2048.png`

### Screenshot 2: FSRS Algorithm
- **Save**: `screenshots_raw/ipad/2_FSRS_Algorithm_2732x2048.png`

### Screenshot 3: Deck Management
- **Note**: Grid layout shows 4-6 decks
- **Save**: `screenshots_raw/ipad/3_Deck_Management_2732x2048.png`

### Screenshot 4: Liquid Glass Study (HERO)
- **Note**: Flashcard is 40-50% of screen (larger than iPhone)
- **Save**: `screenshots_raw/ipad/4_Liquid_Glass_Study_2732x2048.png`

### Screenshot 5: Smart Rating
- **Save**: `screenshots_raw/ipad/5_Smart_Rating_2732x2048.png`

### Screenshot 6: Study Modes
- **Save**: `screenshots_raw/ipad/6_Study_Modes_2732x2048.png`

## iPad-Specific Considerations

### Landscape vs Portrait

**Landscape** (recommended for screenshots):
- Better for studying
- Shows more content
- More screen real estate

**Portrait**:
- Supported by app
- Not primary for screenshots

### Split View Showcase

Consider showing split view in one screenshot to demonstrate iPad capabilities:
- Study session on left
- Deck list on right
- **Optional**: Only if time permits

### Grid vs List Layout

**Grid** (recommended for iPad screenshots):
- Shows 4-6 decks
- Better use of space
- More visually appealing

**List**:
- Supported by app
- Not primary for screenshots

## Post-Processing

```bash
python3 scripts/process_screenshots.py --device ipad_pro_12_9_inch
```

## Quality Checklist

- [ ] Resolution: 2732x2048 (landscape)
- [ ] Orientation is landscape
- [ ] Grid shows 4-6 decks
- [ ] Flashcard is large (40-50% of screen)
- [ ] Glass morphism effects are dramatic
- [ ] Captions sized appropriately (140px, 36pt)
- [ ] No layout issues

## Troubleshooting

**Portrait vs landscape confusion**: Lock orientation in simulator
**Split view obscuring UI**: Ensure only one app is visible
**Keyboard covers UI**: Dismiss keyboard before capturing

## Time Estimate

- Simulator setup: ~15 minutes
- Screenshot capture: ~30-45 minutes
- Post-processing: ~15 minutes
- Review: ~15 minutes
- **Total**: ~1.5-2 hours

## iPad Advantages

1. **Larger Flashcard Display**: 40-50% screen coverage
2. **Enhanced Glass Morphism**: Blur effects more dramatic
3. **Better Deck Management**: Grid shows 4-6 decks
4. **Natural Study Orientation**: Landscape is ideal
5. **Accessibility**: Larger text, better readability
6. **Market Opportunity**: 500M+ iPads sold

## Related Documents

- `docs/ipad-support-decision.md` (Decision analysis)
- `docs/screenshots-plan.md` (Overall strategy)
- `docs/test-data-setup-guide.md` (Data preparation)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
