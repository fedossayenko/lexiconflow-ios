# App Store Video Editing Guide

## Editing Tool Selection Matrix

| Tool | Price | Learning Curve | Best For |
|------|-------|---------------|----------|
| **Final Cut Pro** | $299 (one-time) | Medium | Mac users, professional results |
| **DaVinci Resolve** | Free | Steep | Free option, advanced color grading |
| **iMovie** | Free | Easy | Beginners, simple projects |

**Recommendation**: Final Cut Pro for Mac users, DaVinci Resolve for free option.

---

## Pre-Edit Preparation

### 1. Gather Footage (15 minutes)

- Select best takes for each scene
- Organize in project folder
- Note any issues (bad takes, technical problems)

### 2. Prepare Assets (20 minutes)

- Download background music (royalty-free)
- Create text overlays (copy from storyboard)
- Prepare graphics (Scenes 1 & 6 if not created)

### 3. Project Setup (10 minutes)

- Create new project: 1920x1080, 30 FPS
- Set duration to 30 seconds
- Import footage and assets

---

## Tool-Specific Workflows

### Final Cut Pro

**Import**:
1. File → Import → Media
2. Select all scene footage
3. Create new event: "Lexicon Flow App Store Video"

**Timeline Assembly**:
1. Drag scenes to timeline in order
2. Trim each scene to ~5 seconds
3. Ensure total duration is 27-30 seconds

**Text Overlays**:
1. Titles → Generate Titles
2. Choose Lower Third or basic text
3. Copy text from `app-store-video-editing-quick-reference.md`
4. Position bottom-center, semi-transparent background

**Transitions**:
1. Command+T for Cross Dissolve
2. Apply between all scenes (0.5 seconds)
3. Exception: Scene 3→4 (0.3 second Swipe transition)

**Effects**:
- Scene 3: Badge pulse effect (100% → 110% → 100%, 0.5s)
- Scene 4: Shimmer/glow effect (15-20% amount)
- Scene 6: Button pulse effect

**Export**:
1. File → Share → Master File
2. Settings: 1920x1080, H.264, 8 Mbps VBR 2-pass
3. Export

### DaVinci Resolve

**Import**:
1. Media → Import Media
2. Select footage
3. Create new timeline: 1920x1080, 24fps or 30fps

**Edit**:
1. Switch to Edit tab
2. Drag clips to timeline
3. Trim to ~5 seconds each

**Text**: Fusion tab → Text+
**Transitions**: Video Transitions → Cross Dissolve
**Color**: Color tab (boost brightness +10%, saturation +10%)
**Export**: Deliver tab → QuickTime → H.264 → 1920x1080

### iMovie

**Import** File → Import Media
**Edit**: Drag clips to timeline, trim edges
**Text**: Titles → Lower Third
**Transitions**: Transitions tab → Cross Dissolve
**Export**: File → Share → File

---

## Text Overlays

See `docs/app-store-video-editing-quick-reference.md` for copy-paste templates.

**Typography Standards**:
- Font: SF Pro Display / SF Pro Text
- Weight: Medium (500) or Semibold (600)
- Size: 48-60pt
- Color: White
- Shadow: Drop shadow for readability
- Background: Semi-transparent black overlay

**Scene-by-Scene Text**:
1. Scene 1: "Tired of forgetting vocabulary?" (60pt)
2. Scene 2: "Meet Lexicon Flow" (52pt)
3. Scene 3: "FSRS v5 schedules reviews perfectly" (48pt, indigo highlight)
4. Scene 4: "Beautiful Liquid Glass interface" (50pt)
5. Scene 5: "Study on your terms" (52pt)
6. Scene 6: "Download now / and start learning" (54pt)

---

## Transitions & Effects

### Standard Transitions

**All scenes**: 0.5 second Cross Dissolve
**Exception**: Scene 3→4: 0.3 second Swipe transition

### Scene-Specific Effects

**Scene 3** (FSRS Algorithm):
- Badge pulse: Scale 100% → 110% → 100%
- Duration: 0.5 seconds
- Repeat: 2 pulses

**Scene 4** (Liquid Glass HERO):
- Shimmer effect: 15-20% amount
- Brightness: +10%
- Saturation: +10%

**Scene 5** (Study Modes):
- Button ripple: Scale 100% → 105% → 100%
- Duration: 1 second
- Repeat: 1 pulse

**Scene 6** (CTA):
- Button pulse: Scale 100% → 105% → 100%
- Duration: 1 second
- Repeat: 3 pulses

---

## Audio & Music

### Background Music

**Volume**: 20-30% (dialogue/music balance)
**Fade In**: 1 second at start
**Fade Out**: 1 second at end
**Sources**:
- YouTube Audio Library (free)
- BenSound (free with attribution)
- Pixabay Music (free)
- Epidemic Sound (subscription)

**Style**: Upbeat but subtle, doesn't distract from visuals

### Sound Effects (Optional)

- Button tap sounds ( Scene 5)
- Card flip sound (Scene 4)
- Swipe sound (Scene 3)

---

## Export Settings

### Universal Settings

- **Resolution**: 1920x1080 (1080p)
- **Frame Rate**: 30 FPS
- **Duration**: 27-30 seconds
- **Format**: M4V or MOV
- **Codec**: H.264
- **Bit Rate**: 8 Mbps VBR 2-pass
- **Audio**: AAC 160 kbps (if using music)

### Final Cut Pro Export

File → Share → Master File
- Settings: 1920x1080, H.264, 8 Mbps
- Audio: AAC, 160 kbps

### DaVinci Resolve Export

Deliver tab → QuickTime → H.264
- Resolution: 1920x1080
- Frame rate: 30 fps
- Bit rate: 8 Mbps VBR

### iMovie Export

File → Share → File
- Resolution: 1080p
- Quality: High
- Compress: Better compatibility

---

## Quality Verification

After export, verify:

### Technical
- [ ] Duration: 27-30 seconds
- [ ] Resolution: 1920x1080
- [ ] Frame rate: 30 FPS
- [ ] File size: < 50 MB
- [ ] Format: M4V or MOV

### Content
- [ ] All 6 scenes present
- [ ] Text overlays on all scenes
- [ ] Transitions smooth
- [ ] Glass effects visible (Scene 4)
- [ ] Audio level appropriate (20-30%)
- [ ] No technical glitches

### Device Testing
- [ ] Watch on iPhone
- [ ] Watch on iPad
- [ ] Test in portrait and landscape
- [ ] Verify CTA is compelling

---

## Troubleshooting

### Text Hard to Read

**Problem**: Text overlays not legible
**Solutions**:
- Add drop shadow to text
- Add semi-transparent background
- Increase font size
- Reposition text to clearer area

### Video Too Long

**Problem**: Export is > 30 seconds
**Solutions**:
- Trim scene durations
- Faster transitions (0.3s instead of 0.5s)
- Cut pauses between scenes

### File Size Too Large

**Problem**: Export is > 50 MB
**Solutions**:
- Reduce bit rate to 6 Mbps
- Remove audio (not recommended)
- Use single-pass VBR instead of 2-pass

### Glass Effects Not Visible

**Problem**: Scene 4 doesn't show glass morphism
**Solutions**:
- Boost saturation +15-20%
- Increase brightness +15%
- Add glow/shimmer effect
- Re-record if needed

---

## Time Estimates

### Beginner (8-9 hours)
- Pre-edit: 45 minutes
- Timeline assembly: 1 hour
- Text overlays: 2 hours
- Transitions: 1 hour
- Effects: 1.5 hours
- Audio: 30 minutes
- Export: 30 minutes
- Review/fixes: 1.5 hours

### Experienced (3.5-4 hours)
- Pre-edit: 30 minutes
- Timeline assembly: 30 minutes
- Text overlays: 45 minutes
- Transitions: 30 minutes
- Effects: 45 minutes
- Audio: 15 minutes
- Export: 15 minutes
- Review: 15 minutes

### Time-Saving Tips

- Use templates for text overlays
- Copy-paste text from quick reference
- Batch process similar effects
- Keyboard shortcuts (Final Cut: Cmd+T for transitions)

---

## Success Criteria

Editing phase complete when:
- [ ] Timeline assembled with all 6 scenes
- [ ] Duration 27-30 seconds
- [ ] Text overlays added to all scenes
- [ ] Transitions applied (0.5s crossfade)
- [ ] Scene-specific effects applied
- [ ] Color corrected (brightness +10%, saturation +10%)
- [ ] Audio added at 20-30% volume
- [ ] Exported to M4V/MOV format
- [ ] Tested on iPhone/iPad
- [ ] File size < 50 MB
- [ ] Saved to `fastlane/video/exports/`
- [ ] Project file saved

---

**Document Version**: 1.0
**Last Updated**: 2026-01-06
**Related**: `docs/app-store-preview-video-storyboard.md`, `docs/app-store-video-editing-quick-reference.md`
