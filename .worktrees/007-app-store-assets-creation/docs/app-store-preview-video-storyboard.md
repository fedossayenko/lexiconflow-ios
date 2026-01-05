# App Store Preview Video Storyboard

## Video Specifications

- **Duration**: 30 seconds
- **Resolution**: 1920x1080 (1080p)
- **Aspect Ratio**: 16:9
- **Frame Rate**: 30 FPS
- **Format**: M4V or MOV
- **File Size**: < 50 MB (ideal)

## Scene Breakdown

### Scene 1: Problem (0:00-0:05)

**Duration**: 5 seconds
**Type**: Motion graphic / animated text
**Visual**: Dark background with animated text
**Audio**: Upbeat but subtle background music starts
**Text Overlay**: "Tired of forgetting vocabulary?"

**Action**:
- Text fades in center
- Subtle zoom or scale effect
- Background: Dark gradient

**Text Specs**:
- Font: SF Pro Display Bold
- Size: 60pt
- Color: White

### Scene 2: Welcome Solution (0:05-0:10)

**Duration**: 5 seconds
**Type**: Screen recording
**Visual**: App onboarding screen
**Action**:
- App launches with splash screen
- Onboarding view appears (2 second wait)
- Slow scroll down (0.5 second)
- Pause (2 seconds)

**Text Overlay**: "Meet Lexicon Flow"
**Text Specs**: 52pt, white, semi-transparent background

### Scene 3: FSRS Algorithm (0:10-0:15)

**Duration**: 5 seconds
**Type**: Screen recording
**Visual**: FSRS explanation screen → swipe to deck list
**Action**:
- FSRS algorithm visualization (1.5 second wait)
- Swipe gesture to deck list (0.5 second swipe)
- Deck list appears (2.5 second wait)

**Text Overlay**: "FSRS v5 schedules reviews perfectly"
**Text Specs**: 48pt, white, indigo highlight on "FSRS v5"

### Scene 4: Liquid Glass HERO (0:15-0:20)

**Duration**: 5 seconds
**Type**: Screen recording (HERO scene - most important)
**Visual**: Study session with card flip
**Action**:
- Card front shown (2 seconds)
- Tap to flip (0.5 second animation)
- Card back shown (2.5 seconds)

**Text Overlay**: "Beautiful Liquid Glass interface"
**Text Specs**: 50pt, white, subtle shimmer effect

**Special**: This is the hero scene - spend extra time, ensure glass effects are visible

### Scene 5: Study Modes (0:20-0:25)

**Duration**: 5 seconds
**Type**: Screen recording
**Visual**: Study mode selection → rating buttons
**Action**:
- Tap "Scheduled" mode (0.5 seconds)
- Tap "Cram" mode (0.5 seconds)
- Tap "Scheduled" again (0.5 seconds)
- Tap "Start Studying" (0.5 seconds)
- Show rating buttons (1.5 seconds)
- Tap "Easy" button (1 second)

**Text Overlay**: "Study on your terms"
**Text Specs**: 52pt, white

### Scene 6: Call to Action (0:25-0:30)

**Duration**: 5 seconds
**Type**: Motion graphic
**Visual**: App icon + Download button
**Action**:
- App icon fades in center
- "Download Now" button pulses (3 times)
- Background gradient matches app icon

**Text Overlay**:
- Line 1: "Download now"
- Line 2: "and start learning"

**Text Specs**: 54pt, white, animated

**Button**: Rounded rectangle, indigo fill, "Download" text

## Production Notes

### Device Setup

**Recommended**: iPhone 15 Pro Max simulator
- Largest display for best recording quality
- 1320x2868 resolution downscaled to 1920x1080
- Ensure status bar shows 9:41 AM

### Simulator Settings

- Light Mode
- Reduce Transparency: OFF
- 100% scale
- Do Not Disturb: ON
- No animations: Reduce Motion ON (for smoother recording)

### Test Data

Same as screenshots:
- 3 decks
- 10 flashcards per deck
- 5-8 cards marked as "due"

### Recording Best Practices

1. **Slow Movements**: All interactions should be deliberate and slow
2. **Intentional Pauses**: Wait 1-2 seconds after each action
3. **Gentle Taps**: No rapid tapping or swiping
4. **Multiple Takes**: Record each scene 2-3 times
5. **HERO Scene**: Scene 4 requires 3-4 takes for best result

### File Organization

```
fastlane/video/raw_footage/
  scene1_problem_take1.mov
  scene1_problem_take2.mov
  scene2_welcome_take1.mov
  scene3_fsrs_take1.mov
  scene4_liquid_glass_take1.mov
  scene4_liquid_glass_take2.mov (HERO - multiple takes)
  scene5_modes_take1.mov
  scene6_cta_take1.mov
```

## Post-Production

### Editing Tools

- **Final Cut Pro** (recommended for Mac)
- **DaVinci Resolve** (free, cross-platform)
- **iMovie** (simple, Mac only)

### Text Overlays

See `docs/app-store-video-editing-quick-reference.md` for copy-paste templates.

### Transitions

- **Standard**: 0.5 second crossfade between all scenes
- **Exception**: Scene 3→4: 0.3 second swipe transition

### Color Correction

- Boost brightness: +10%
- Boost saturation: +10%
- Make glass effects pop

### Audio

- Background music: 20-30% volume
- Fade in/out: 1 second at start/end
- Royalty-free sources: YouTube Audio Library, BenSound, Pixabay

### Export Settings

**Final Cut Pro**:
- Format: M4V
- Resolution: 1920x1080
- Codec: H.264
- Bit Rate: 8 Mbps VBR 2-pass
- Audio: AAC 160 kbps

**DaVinci Resolve**:
- Format: QuickTime or MP4
- Codec: H.264
- Resolution: 1920x1080
- Frame Rate: 30 fps

## Quality Checklist

- [ ] Duration: 27-30 seconds (App Store limit)
- [ ] Resolution: 1920x1080 (16:9)
- [ ] Frame rate: 30 FPS
- [ ] Format: M4V or MOV
- [ ] File size: < 50 MB
- [ ] All 6 scenes present
- [ ] Text overlays on all scenes
- [ ] Transitions smooth (0.5s crossfade)
- [ ] Glass effects visible (especially Scene 4)
- [ ] Audio level: 20-30% background music
- [ ] No status bar artifacts
- [ ] No notifications visible

## Success Metrics

- **Watch Rate**: % of viewers who watch entire video
- **Conversion Rate**: % who download after watching
- **Retention**: Drop-off points in video

## Time Estimates

- **Recording**: 3-4 hours (including multiple takes)
- **Editing**: 3.5-9 hours (beginner: 8-9 hours, experienced: 3.5-4 hours)
- **Total**: 6.5-13 hours

## Related Documents

- `docs/app-store-video-recording-guide.md` (Detailed recording instructions)
- `docs/app-store-video-editing-guide.md` (Comprehensive editing guide)
- `docs/app-store-video-editing-quick-reference.md` (Copy-paste templates)
- `fastlane/video/README.md` (File organization)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Status**: Ready for video production
