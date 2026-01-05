# App Store Video Recording Guide

## Prerequisites

- Xcode with iOS project
- iOS Simulator (iPhone 15 Pro Max recommended)
- Test data prepared (see `test-data-setup-guide.md`)
- 3-4 hours available

---

## Device Setup

### Recommended: iPhone 15 Pro Max Simulator

**Why**:
- Largest display (6.7") for best recording quality
- High-resolution footage (1320x2868 downscaled to 1920x1080)
- Dynamic Island looks modern

### Simulator Configuration

**Display Settings**:
- Mode: Light Mode
- Reduce Transparency: OFF (critical for glass effects)
- Scale: 100%
- Time: 9:41 AM (Command+Shift+T)
- Battery: 100%

**System Settings**:
- Do Not Disturb: ON
- Notifications: None
- Wallpaper: Clean, minimal

---

## Test Data Setup

See `docs/test-data-setup-guide.md` for complete instructions.

**Quick Setup**:
1. Create 3 decks
2. Add 10 flashcards per deck
3. Words: "Ephemeral", "Serendipity", "Eloquent", "Ubiquitous", "Resilient", "Meticulous", "Pragmatic", "Ambiguous", "Eloquent", "Cacophony"
4. Mark 5-8 cards as "due"

---

## Recording Instructions

### Scene 1: Problem Graphic (0:00-0:05)

**Type**: Motion graphic (design tool)
**Duration**: 5 seconds
**Not recorded in simulator** - create in Figma, After Effects, or similar

**File**: `scene1_problem_take1.mov`

### Scene 2: Welcome Onboarding (0:05-0:10)

**View**: `OnboardingView`
**Actions**:
1. Navigate to onboarding screen
2. Wait 2 seconds (let viewer read)
3. Slow scroll down (0.5 second swipe)
4. Wait 2 seconds

**Record**:
1. Press Command+Shift+5
2. Select record area (entire simulator)
3. Click Record
4. Perform actions
5. Stop recording

**File**: `scene2_welcome_take1.mov`

### Scene 3: FSRS Algorithm (0:10-0:15)

**View**: FSRS explanation → Deck list
**Actions**:
1. Show FSRS page (1.5 second wait)
2. Swipe to deck list (0.5 second slow swipe)
3. Show deck list (2.5 second wait)

**File**: `scene3_fsrs_take1.mov`

### Scene 4: Liquid Glass HERO (0:15-0:20) ⭐ MOST IMPORTANT

**View**: `StudySessionView` (card flip)
**Actions**:
1. Navigate to study session
2. Show card front (2 seconds)
3. Tap card to flip (0.5 second)
4. Show card back (2.5 seconds)

**Record 3-4 takes** - this is the hero scene!

**Files**:
- `scene4_liquid_glass_take1.mov`
- `scene4_liquid_glass_take2.mov`
- `scene4_liquid_glass_take3.mov`

### Scene 5: Study Modes (0:20-0:25)

**View**: `StudyView` → Rating
**Actions**:
1. Show mode selector (1 second)
2. Tap "Scheduled" (0.5 seconds)
3. Tap "Cram" (0.5 seconds)
4. Tap "Scheduled" again (0.5 seconds)
5. Tap "Start Studying" (0.5 seconds)
6. Show rating buttons (1.5 seconds)
7. Tap "Easy" (1 second)

**File**: `scene5_modes_take1.mov`

### Scene 6: CTA Graphic (0:25-0:30)

**Type**: Motion graphic (design tool)
**Duration**: 5 seconds
**Not recorded in simulator** - create in Figma, After Effects

**File**: `scene6_cta_take1.mov`

---

## Recording Best Practices

### Smooth Movements

- All gestures should be slow and deliberate
- No rapid tapping or swiping
- Pause 1-2 seconds after each action
- Let viewer absorb information

### Intentional Pauses

- Wait 2 seconds on each screen
- Wait 1-2 seconds after gestures complete
- Let animations finish before cutting

### Gentle Taps

- Don't tap rapidly
- Single taps, not double-taps
- Tap center of buttons (not edges)

### Multiple Takes

- Record each scene 2-3 times
- HERO scene (Scene 4): 3-4 takes
- Label files clearly: `scene{number}_{description}_take{number}.mov`

### Glass Effect Visibility

**Critical**: Ensure glass morphism effects are visible
- Light Mode only
- Reduce Transparency: OFF
- Test recording before committing
- Glass thickness should be clearly visible

---

## File Organization

```
fastlane/video/raw_footage/
  scene1_problem_take1.mov
  scene2_welcome_take1.mov
  scene3_fsrs_take1.mov
  scene4_liquid_glass_take1.mov
  scene4_liquid_glass_take2.mov
  scene4_liquid_glass_take3.mov
  scene5_modes_take1.mov
  scene6_cta_take1.mov
  README.md (scene breakdown, notes)
```

---

## Quality Verification

After each scene, verify:

- [ ] Footage is smooth (no lag/stutter)
- [ ] Glass effects are visible
- [ ] Status bar shows 9:41 AM
- [ ] No notifications visible
- [ ] No mouse cursor in recording
- [ ] Audio is clear (if recording system audio)
- [ ] Duration is correct (~5 seconds per scene)

---

## Troubleshooting

### Simulator Lag

**Problem**: Recording is choppy/laggy
**Solutions**:
- Close other apps
- Restart simulator
- Reduce recording resolution
- Use physical device instead

### Glass Effects Not Visible

**Problem**: Glass morphism not showing in recording
**Solutions**:
- Ensure Reduce Transparency is OFF
- Use Light Mode (not Dark Mode)
- Boost brightness if needed
- Test on physical device

### Status Bar Artifacts

**Problem**: Time, battery, signal showing inconsistently
**Solutions**:
- Set time to 9:41 AM before recording
- Enable Do Not Disturb
- Hide status bar in simulator settings

### Recording Tool Issues

**Problem**: Command+Shift+5 not working
**Solutions**:
- Use QuickTime Player screen recording
- Use third-party tool (CleanShot X, Kap)
- Record on physical device with QuickTime

---

## Recording Tools

### Built-in (Free)

- **macOS Screen Recording**: Command+Shift+5
- **QuickTime Player**: File → New Screen Recording

### Third-Party

- **CleanShot X** ($29): Powerful screenshot/screen recording tool
- **Kap** (Free): Open-source screen recorder
- **ScreenFlow** ($149): Professional screen recording and editing

### Physical Device Recording

1. Connect iPhone/iPad to Mac via USB
2. Open QuickTime Player
3. File → New Movie Recording
4. Select device from dropdown
5. Record device screen

---

## Time Estimate

- **Setup**: 30 minutes (simulator config, test data)
- **Recording**: 2 hours (6 scenes × 2-3 takes each)
- **Review**: 30 minutes (watch footage, select best takes)
- **Organization**: 30 minutes (file naming, organization)
- **Total**: 3-4 hours

---

## Next Steps

After recording:
1. Select best takes for each scene
2. Import into editing tool (Final Cut Pro, DaVinci Resolve, iMovie)
3. See `docs/app-store-video-editing-guide.md` for editing instructions

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Related**: `docs/app-store-preview-video-storyboard.md`, `docs/app-store-video-editing-guide.md`
