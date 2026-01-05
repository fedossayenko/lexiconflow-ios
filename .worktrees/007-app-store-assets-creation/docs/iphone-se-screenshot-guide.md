# iPhone SE Screenshot Guide

## Device Specifications

**iPhone SE (3rd Generation)**
- Screen Size: 4.7" (diagonal)
- Resolution: 640x1136 pixels
- Status Bar: 20px
- Home Button: Physical (no home indicator)
- Safe Area Top: 20px
- Safe Area Bottom: 0px
- Screenshot Resolution: 640x1136
- Caption Height: 80px
- Caption Font Size: 20pt

## Simulator Setup

1. **Open Xcode**
2. **Select Simulator**: iPhone SE (3rd generation)
3. **Configure Settings**:
   - Display Mode: Light
   - Reduce Transparency: OFF (Settings → Accessibility → Display & Text Size)
   - Time: 9:41 AM (Command+Shift+T in simulator)
   - Battery: 100%
   - Do Not Disturb: ON

## Test Data Setup

See `docs/test-data-setup-guide.md` for complete instructions.

**Quick Setup**:
- Create 3 decks
- Add 10 flashcards per deck
- Mark 5-8 cards as "due"

## Screenshot Capture

### Screenshot 1: Welcome
- **View**: `OnboardingView`
- **Action**: Navigate to welcome screen
- **Position**: Content centered vertically
- **Capture**: Command+Shift+S
- **Save**: `screenshots_raw/iphone_se/1_Welcome_640x1136.png`

### Screenshot 2: FSRS Algorithm
- **View**: FSRS explanation page
- **Action**: Scroll to algorithm visualization
- **Capture**: Command+Shift+S
- **Save**: `screenshots_raw/iphone_se/2_FSRS_Algorithm_640x1136.png`

### Screenshot 3: Deck Management
- **View**: `DeckListView`
- **Action**: Ensure 3-4 decks visible
- **Capture**: Command+Shift+S
- **Save**: `screenshots_raw/iphone_se/3_Deck_Management_640x1136.png`

### Screenshot 4: Liquid Glass Study (HERO)
- **View**: `StudySessionView` + `CardFrontView`
- **Action**: Ensure glass thickness is visible
- **Capture**: Command+Shift+S (take 2-3 shots)
- **Save**: `screenshots_raw/iphone_se/4_Liquid_Glass_Study_640x1136.png`
- **Note**: This is the hero screenshot - spend extra time

### Screenshot 5: Smart Rating
- **View**: `StudySessionView` + `CardBackView` + `RatingButtonsView`
- **Action**: Flip card, show rating buttons
- **Capture**: Command+Shift+S
- **Save**: `screenshots_raw/iphone_se/5_Smart_Rating_640x1136.png`

### Screenshot 6: Study Modes
- **View**: `StudyView`
- **Action**: Show mode selector (Scheduled/Cram)
- **Capture**: Command+Shift+S
- **Save**: `screenshots_raw/iphone_se/6_Study_Modes_640x1136.png`

## Post-Processing

**Automated** (recommended):
```bash
python3 scripts/process_screenshots.py --device iphone_se
```

**Manual**:
1. Add device frame (optional)
2. Add caption overlay (80px height, 20pt font)
3. Optimize file size
4. Save to `fastlane/screenshots/iphone_se/`

## Quality Checklist

- [ ] All 6 screenshots captured
- [ ] Resolution is 640x1136
- [ ] Content is centered and visible
- [ ] Glass morphism effects are visible
- [ ] No status bar notifications
- [ ] Time shows 9:41 AM
- [ ] File size < 500KB each

## Troubleshooting

**Simulator lag**: Restart simulator, close other apps
**Glass effects not visible**: Ensure Reduce Transparency is OFF
**Status bar artifacts**: Clean status area before capturing

## Time Estimate

- Capture: ~30 minutes
- Post-processing: ~15 minutes (with script)
- **Total**: ~45 minutes

---

**Related**: `docs/screenshots-plan.md`, `scripts/process_screenshots.py`
