# Screenshots Plan

## Overview

This document defines the screenshot strategy for Lexicon Flow's App Store listing, including which screens to showcase, narrative flow, visual design specifications, and device-specific requirements.

## Screenshot Concepts (6 Screens)

### Screenshot 1: Welcome / Onboarding

**Screen**: `OnboardingView` (Page 1 or 2)
**Caption**: "Master vocabulary with advanced spaced repetition"
**Visual Focus**:
- Welcome message with tagline
- Clean, minimal onboarding UI
- Glass morphism cards visible

**Purpose**: Hook users with clear value proposition

### Screenshot 2: FSRS Algorithm Explanation

**Screen**: `OnboardingView` (FSRS explanation page) or dedicated algorithm info view
**Caption**: "FSRS v5 optimizes your study schedule for 90% retention"
**Visual Focus**:
- Algorithm visualization (graph or chart)
- Key benefits highlighted in glass cards
- Comparison with traditional methods

**Purpose**: Establish scientific credibility

### Screenshot 3: Deck Management

**Screen**: `DeckListView`
**Caption**: "Organize your vocabulary with smart deck management"
**Visual Focus**:
- 3-4 vocabulary decks visible
- Glass card thickness showing memory stability
- Deck statistics (cards due, mastered)
- Clean grid/list layout

**Purpose**: Show organizational capabilities

### Screenshot 4: Liquid Glass Study Session (HERO)

**Screen**: `StudySessionView` with `CardFrontView`
**Caption**: "Beautiful Liquid Glass interface shows memory strength"
**Visual Focus**:
- Flashcard with glass morphism effect
- Glass thickness representing memory stability
- Elegant typography
- Subtle animations (if possible in static screenshot)

**Purpose**: Hero screenshot showcasing unique differentiator

### Screenshot 5: Smart Rating System

**Screen**: `StudySessionView` with `CardBackView` + `RatingButtonsView`
**Caption**: "Intelligent ratings adapt to your learning patterns"
**Visual Focus**:
- Card back with answer
- Rating buttons (Again, Hard, Good, Easy)
- Visual feedback on glass thickness change
- Swipe gesture hint

**Purpose**: Show FSRS algorithm in action

### Screenshot 6: Study Modes

**Screen**: `StudyView` with mode selector (Scheduled vs. Cram)
**Caption**: "Study on your terms: Scheduled review or Cram mode"
**Visual Focus**:
- Segmented picker or tabs for study modes
- Mode explanation text
- Cards due count
- Start Studying button

**Purpose**: Demonstrate user agency and flexibility

## Narrative Flow

The screenshots create a compelling narrative:

1. **Problem/Solution** (Screenshot 1-2): "Struggling with vocabulary? FSRS v5 is the solution"
2. **Organization** (Screenshot 3): "Here's how you organize your learning"
3. **Differentiation** (Screenshot 4): "Look at this beautiful Liquid Glass interface"
4. **In Action** (Screenshot 5): "See how intelligent ratings optimize your study"
5. **Flexibility** (Screenshot 6): "Study your way - on your terms"

## Device Specifications

### iPhone SE (3rd Generation)

```
Screen Size: 4.7" (diagonal)
Resolution: 640x1136 pixels
Aspect Ratio: 16:9
Status Bar: 20px
Home Indicator: 0px (physical home button)
Safe Area Top: 20px
Safe Area Bottom: 0px
Screenshot Resolution: 640x1136
Caption Height: 80px
Caption Font Size: 20pt
```

### iPhone 15

```
Screen Size: 6.1" (diagonal)
Resolution: 1290x2796 pixels
Aspect Ratio: 19.5:9
Status Bar: 54px (Dynamic Island)
Home Indicator: 18px
Safe Area Top: 54px
Safe Area Bottom: 34px
Screenshot Resolution: 1290x2796
Caption Height: 100px
Caption Font Size: 26pt
```

### iPhone 15 Pro Max

```
Screen Size: 6.7" (diagonal)
Resolution: 1320x2868 pixels
Aspect Ratio: 19.5:9
Status Bar: 59px (Dynamic Island, larger)
Home Indicator: 18px
Safe Area Top: 59px
Safe Area Bottom: 34px
Screenshot Resolution: 1320x2868
Caption Height: 110px
Caption Font Size: 28pt
```

### iPad Pro 12.9"

```
Screen Size: 12.9" (diagonal)
Resolution: 2732x2048 pixels (landscape)
Aspect Ratio: 4:3 (landscape) / 3:4 (portrait)
Status Bar: 24px
Home Indicator: 20px
Safe Area Top: 24px
Safe Area Bottom: 20px
Screenshot Resolution: 2732x2048 (landscape)
Caption Height: 140px
Caption Font Size: 36pt
```

## Visual Design Guidelines

### Color Palette

```
Primary: #6366F1 (Indigo 500)
Secondary: #EC4899 (Pink 500)
Accent: #8B5CF6 (Purple 500)
Background: Gradient or solid light color
Text: #1F2937 (Gray 800)
Captions: Semi-transparent white overlay
```

### Typography

```
App Font: SF Pro (system font)
Caption Font: SF Pro Text / SF Pro Display
Caption Weight: Medium (500) or Semibold (600)
Caption Color: White with text shadow for readability
```

### Glass Morphism Effects

**Glass Card**:
- Background blur: 20-40px
- Opacity: 20-30%
- Border: 1px solid white, 30-40% opacity
- Corner radius: 12-16px
- Shadow: Subtle drop shadow

**Caption Overlay**:
- Background: rgba(0, 0, 0, 0.6-0.7)
- Height: As per device specifications (80-140px)
- Padding: 16-24px
- Position: Bottom of screenshot
- Corner radius: Optional (12-16px at top)

### Design Principles

1. **Consistency**: Same 6 screenshots across all devices
2. **Simplicity**: Don't clutter with too much UI
3. **Focus**: Highlight the key feature/message of each screen
4. **Beauty**: Liquid Glass UI must look stunning
5. **Legibility**: Captions must be readable at all sizes
6. **Authenticity**: Use real app UI, not mockups

## Device Frame Decision

**Decision: Use frames for all screenshots**

**Rationale**:
- Premium, professional appearance
- Clarifies device context
- App Store preview shows device frame anyway
- Better showcases Liquid Glass UI on device

**Frame Sources**:
- [Apple Design Resources](https://developer.apple.com/design/resources/)
- [MockupPhone](https://mockupphone.com/)
- [Smartmockups](https://smartmockups.com/)
- [Placeit](https://placeit.net/)

**Frame Guidelines**:
- Use official Apple device frames
- Ensure frame is high-resolution (2x or 3x)
- Frame should not obscure important UI elements
- Frame color/finish: Space Gray or Silver (neutral)

## Screenshot Capture Workflow

### Phase 1: Test Data Setup

See `docs/test-data-setup-guide.md` for detailed instructions.

**Quick Summary**:
1. Create 3 decks (e.g., "GRE Vocabulary", "Spanish Basics", "Medical Terms")
2. Add 10 interesting flashcards per deck
3. Mark 5-8 cards as "due" for study session screenshots
4. Test data words: "Ephemeral", "Serendipity", "Eloquent", "Ubiquitous", "Resilient", etc.

### Phase 2: Simulator Configuration

**Common Settings** (all devices):
- Display Mode: Light Mode
- Reduce Transparency: OFF (to show glass effects)
- Time: 9:41 AM (Apple convention)
- Battery: 100%
- Do Not Disturb: ON
- Notifications: None
- Wallpaper: Clean, minimal

**Device-Specific**:
- iPhone SE: Set simulator to iPhone SE (3rd generation)
- iPhone 15: Set simulator to iPhone 15
- iPhone 15 Pro Max: Set simulator to iPhone 15 Pro Max
- iPad: Set simulator to iPad Pro (12.9-inch)

### Phase 3: Screenshot Capture

**Tool**: iOS Simulator built-in screenshot (Command+Shift+S)

**Per-Screenshot Instructions**:

**Screenshot 1: Welcome**
1. Launch app
2. Navigate to `OnboardingView`
3. Position content vertically centered
4. Command+Shift+S
5. Name: `1_Welcome_640x1136.png` (adjust resolution per device)

**Screenshot 2: FSRS Algorithm**
1. Navigate to FSRS explanation page
2. Ensure algorithm visualization is visible
3. Command+Shift+S
4. Name: `2_FSRS_Algorithm_640x1136.png`

**Screenshot 3: Deck Management**
1. Navigate to `DeckListView`
2. Ensure 3-4 decks are visible
3. Command+Shift+S
4. Name: `3_Deck_Management_640x1136.png`

**Screenshot 4: Liquid Glass Study (HERO)**
1. Navigate to `StudySessionView`
2. Ensure card front is prominent
3. Glass thickness should be clearly visible
4. Take 2-3 shots to get best angle
5. Command+Shift+S
6. Name: `4_Liquid_Glass_Study_640x1136.png`
7. **Note**: This is the hero screenshot - spend extra time

**Screenshot 5: Smart Rating**
1. In study session, tap card to flip
2. Ensure rating buttons are visible
3. Show glass thickness change if animated
4. Command+Shift+S
5. Name: `5_Smart_Rating_640x1136.png`

**Screenshot 6: Study Modes**
1. Navigate to `StudyView`
2. Ensure mode selector (Scheduled/Cram) is visible
3. Command+Shift+S
4. Name: `6_Study_Modes_640x1136.png`

### Phase 4: Post-Processing

See `scripts/process_screenshots.py` for automated processing.

**Manual Processing Steps** (if not using script):
1. Add device frame (if using frames)
2. Add caption overlay with semi-transparent background
3. Optimize file size (use ImageOptim or TinyPNG)
4. Verify final resolution matches specification
5. Save to `fastlane/screenshots/{device}/`

## File Naming Convention

```
{Number}_{Title}_{Width}x{Height}.png

Examples:
1_Welcome_640x1136.png
2_FSRS_Algorithm_640x1136.png
3_Deck_Management_640x1136.png
4_Liquid_Glass_Study_640x1136.png
5_Smart_Rating_640x1136.png
6_Study_Modes_640x1136.png
```

## Post-Processing Script

See `scripts/process_screenshots.py` for automated:
- Device frame application
- Caption overlay with semi-transparent background
- File optimization
- Batch processing for multiple devices

**Usage**:
```bash
python3 scripts/process_screenshots.py --device iphone_se
python3 scripts/process_screenshots.py --device iphone_15
python3 scripts/process_screenshots.py --device iphone_15_pro_max
python3 scripts/process_screenshots.py --device ipad_pro_12_9_inch
python3 scripts/process_screenshots.py --all  # Process all devices
```

## Preparation Checklist

Before capturing screenshots:

- [ ] Test data prepared (3 decks, 30 cards total)
- [ ] Simulator configured for each device
- [ ] App built and running on simulator
- [ ] Screenshots plan reviewed and understood
- [ ] Device frames sourced (if using frames)
- [ ] Post-processing script tested
- [ ] Output directories created (`fastlane/screenshots/{device}/`)

## Success Criteria

Screenshots are successful when:

- [ ] All 6 screenshots captured for each device
- [ ] Screenshots match resolution specifications
- [ ] Captions are clear and compelling
- [ ] Glass morphism effects are visible
- [ ] Liquid Glass UI looks beautiful
- [ ] Screenshots tell cohesive narrative
- [ ] File sizes are optimized (< 500KB each)
- [ ] Frames are applied consistently (if using)

## A/B Testing Considerations

Consider testing alternative screenshot orders:

**Option A (Current)**: Feature-focused
1. Welcome → FSRS → Decks → Glass Study → Rating → Modes

**Option B**: Problem-solution
1. Glass Study (hero first) → Decks → Rating → Modes → FSRS → Welcome

**Option C**: Benefit-focused
1. Rating → Glass Study → Modes → Decks → FSRS → Welcome

Track conversion rates in App Store Analytics to determine optimal order.

## Competitive Analysis

**AnkiMobile**:
- Shows simple app interface
- No device frames
- Plain captions
- Focuses on features over aesthetics

**Quizlet**:
- Colorful, engaging screenshots
- Uses device frames
- Shows social features
- Emphasizes gamification

**Brainscape**:
- Professional screenshots
- Shows study dashboard
- Uses device frames
- Focuses on learning science

**Lexicon Flow Differentiation**:
- Beautiful Liquid Glass UI (unique aesthetic)
- Glass thickness visualization (novel feature)
- FSRS v5 algorithm (scientific advantage)
- User agency (two study modes)

## Timeline Estimates

**Per Device**:
- Test data setup: 30 minutes
- Simulator setup: 15 minutes
- Screenshot capture: 30-45 minutes
- Post-processing: 15 minutes (with script)
- Review and refinement: 30 minutes

**Total per device**: ~2-2.5 hours

**All 4 devices**: ~8-10 hours

**With automation script**: ~6-8 hours

## Related Documents

- `docs/test-data-setup-guide.md` - Preparing flashcard data
- `docs/iphone-se-screenshot-guide.md` - iPhone SE-specific instructions
- `docs/iphone-15-screenshot-guide.md` - iPhone 15-specific instructions
- `docs/iphone-15-pro-max-screenshot-guide.md` - iPhone 15 Pro Max-specific instructions
- `docs/ipad-screenshot-guide.md` - iPad-specific instructions
- `scripts/process_screenshots.py` - Automated post-processing script

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Status**: Ready for screenshot capture
