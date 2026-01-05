# Fastlane Directory - App Store Assets

This directory contains all App Store submission assets and automation scripts for LexiconFlow.

---

## Directory Structure

```
fastlane/
├── README.md (this file)
├── Fastfile (automation lanes)
├── screenshots/
│   ├── iphone_se/        # 6 screenshots @ 750x1334
│   ├── iphone_15/        # 6 screenshots @ 1179x2556
│   ├── iphone_15_pro_max/ # 6 screenshots @ 1290x2796
│   └── ipad/             # 6 screenshots @ 1640x2360
└── video/
    ├── raw_footage/      # Raw screen recordings (6 scenes)
    └── exports/          # Final 30-second preview video
```

---

## Screenshots

### Overview

Total screenshots: **24** (6 per device × 4 devices)

### Screenshot Narrative Flow

Each device has 6 screenshots telling a progressive story:

1. **Forget Less** - Problem hook ("Tired of forgetting what you learn?")
2. **FSRS v5** - Algorithm showcase ("90% retention with FSRS v5 algorithm")
3. **Liquid Glass** - UI demonstration ("Beautiful Liquid Glass interface")
4. **Study Modes** - Feature highlight ("Flashcards, Quiz, and Writing modes")
5. **Smart Scheduling** - Benefit statement ("Smart scheduling optimizes study time")
6. **Start Learning** - Call to action ("Start learning vocabulary today")

### Device Specifications

| Device | Resolution | Scale | Directory | Screenshots |
|--------|------------|-------|-----------|-------------|
| iPhone SE | 750×1334 | @2x | `screenshots/iphone_se/` | 6 |
| iPhone 15 | 1179×2556 | @3x | `screenshots/iphone_15/` | 6 |
| iPhone 15 Pro Max | 1290×2796 | @3x | `screenshots/iphone_15_pro_max/` | 6 |
| iPad (10th Gen) | 1640×2360 | @2x | `screenshots/ipad/` | 6 |

### File Naming Convention

```
{Number}_{Title}_{Width}x{Height}.png

Examples:
- 1_FORGET_LESS_750x1334.png
- 2_FSRS_V5_1179x2556.png
- 3_LIQUID_GLASS_1290x2796.png
```

### Captions

All screenshots have semi-transparent caption overlays at the bottom 20% with the following text:

- Screenshot 1: "Tired of forgetting what you learn?"
- Screenshot 2: "90% retention with FSRS v5 algorithm"
- Screenshot 3: "Beautiful Liquid Glass interface"
- Screenshot 4: "Flashcards, Quiz, and Writing modes"
- Screenshot 5: "Smart scheduling optimizes study time"
- Screenshot 6: "Start learning vocabulary today"

---

## Video

### Preview Video Specification

- **Duration**: 27-30 seconds
- **Resolution**: 1920×1080 (1080p)
- **Format**: M4V or MOV
- **Codec**: H.264
- **Frame Rate**: 30 FPS
- **File Size**: Under 50 MB
- **Location**: `video/exports/lexicon_flow_preview_1080p.m4v`

### Video Storyboard (6 Scenes)

| Scene | Duration | Content | Text Overlay |
|-------|----------|---------|--------------|
| 1 | 0:00-0:02 | Problem graphic (forgetting curve) | "Tired of forgetting?" |
| 2 | 0:02-0:07 | Welcome/onboarding screen | "LexiconFlow" |
| 3 | 0:07-0:12 | FSRS algorithm page | "FSRS v5: 90% retention" |
| 4 | 0:12-0:17 | Liquid Glass HERO card flip | "Beautiful Liquid Glass" |
| 5 | 0:17-0:22 | Study modes carousel | "Multiple study modes" |
| 6 | 0:22-0:27 | CTA graphic (app icon + download) | "Start learning today" |

**Transitions**: 0.5s crossfade between scenes
**Text Overlay**: San Francisco font, 48-60pt, white with shadow

### Production Workflow

1. **Record Raw Footage** (`video/raw_footage/`)
   - Use iOS Simulator screen recording
   - Capture each scene separately
   - Include 2-3 second buffer before/after

2. **Edit in Final Cut Pro / iMovie / DaVinci Resolve**
   - Assemble scenes in order
   - Add crossfade transitions
   - Add text overlays
   - Apply color correction (+10% brightness, +10% saturation)

3. **Export Settings**
   - Format: M4V (H.264)
   - Resolution: 1920×1080
   - Frame rate: 30 FPS
   - Bit rate: VBR, 8-10 Mbps
   - Audio: AAC, 128 kbps (if including music)

4. **Quality Check**
   - Duration: 27-30 seconds
   - File size: Under 50 MB
   - Text legible on iPhone/iPad
   - Smooth playback

---

## Fastfile Automation

### Available Lanes

#### `upload_app_store_assets`
Uploads screenshots and app icon to App Store Connect.

```bash
fastlane upload_app_store_assets
```

#### `upload_metadata`
Uploads promotional text, description, and keywords to App Store Connect.

```bash
fastlane upload_metadata
```

#### `upload_all_assets`
Uploads everything (screenshots + icon + metadata).

```bash
fastlane upload_all_assets
```

#### `verify_screenshots`
Validates screenshots meet App Store requirements before upload.

```bash
fastlane verify_screenshots
```

#### `generate_icons`
Generates all iOS icon sizes from 1024×1024 master.

```bash
fastlane generate_icons
```

#### `process_screenshots`
Processes raw screenshots with captions and frames.

```bash
fastlane process_screenshots device:iphone_se
```

---

## App Store Connect Submission

### Manual Submission Steps

1. **Login** to App Store Connect
2. **Navigate** to My Apps → LexiconFlow
3. **Upload Screenshots**
   - Go to App Store Connect → LexiconFlow → App Store → Screenshots
   - Drag and drop screenshots for each device
   - Or use fastlane: `fastlane upload_app_store_assets`

4. **Upload App Icon**
   - Should be auto-updated via asset catalog
   - Verify in App Store Connect

5. **Upload Preview Video** (MANUAL)
   - Go to App Store Connect → App Store → App Preview
   - Upload `video/exports/lexicon_flow_preview_1080p.m4v`
   - **Note**: fastlane cannot upload videos; must be done manually

6. **Enter Metadata**
   - Go to App Information
   - Copy/paste from `docs/`:
     - Promotional text: `app-store-promotional-text.md` (170 chars)
     - Description: `app-store-description.md` (3,847 chars)
     - Keywords: `app-store-keywords.md` (100 chars)
   - Or use fastlane: `fastlane upload_metadata`

7. **Review** all assets for accuracy
8. **Submit for Review** when ready

### Automated Submission (Recommended)

```bash
# Upload everything except video (manual)
fastlane upload_all_assets

# Then manually upload preview video in App Store Connect
```

---

## Asset Validation

### Pre-Submission Checklist

#### Screenshots
- [ ] All 24 screenshots present (6 per device × 4 devices)
- [ ] Resolution matches device spec exactly
- [ ] PNG format, lossless
- [ ] Captions visible and legible
- [ ] No simulator chrome or artifacts
- [ ] File sizes under 5 MB each

#### App Icon
- [ ] 1024×1024 PNG
- [ ] Glass morphism design (fluid 'L')
- [ ] No transparency (solid background)
- [ ] File size under 500 KB

#### Preview Video
- [ ] Duration: 27-30 seconds
- [ ] Resolution: 1920×1080
- [ ] Format: M4V/MOV, H.264 codec
- [ ] File size under 50 MB
- [ ] Text overlays legible
- [ ] Plays correctly on iPhone/iPad

#### Metadata
- [ ] Promotional text: 170 characters
- [ ] Description: under 4,000 characters
- [ ] Keywords: 100 characters
- [ ] No typos or grammatical errors

---

## Related Documentation

### Design Documents
- [App Icon Design Concept](../docs/app-icon-design-concept.md)
- [Screenshots Plan](../docs/screenshots-plan.md)
- [iPhone SE Screenshot Guide](../docs/iphone-se-screenshot-guide.md)
- [Test Data Setup Guide](../docs/test-data-setup-guide.md)

### App Store Copy
- [Promotional Text](../docs/app-store-promotional-text.md)
- [Description](../docs/app-store-description.md)
- [Keywords](../docs/app-store-keywords.md)
- [Compiled Copy Package](../docs/app-store-copy.md)

### Video Documentation
- [Preview Video Storyboard](../docs/app-store-preview-video-storyboard.md)
- [Recording Guide](../docs/app-store-video-recording-guide.md)
- [Editing Guide](../docs/app-store-video-editing-guide.md)

### Scripts
- [Generate Icon Variants](../scripts/generate-icon-variants.py)
- [Process Screenshots](../scripts/process_screenshots.py)
- [Validate App Store Assets](../scripts/validate_app_store_assets.py)

---

## Support

### Fastlane Documentation
- Official Docs: https://docs.fastlane.tools/
- App Store Upload: https://docs.fastlane.tools/actions/upload_to_app_store/

### Apple Resources
- App Store Connect: https://appstoreconnect.apple.com/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

---

## Status

| Asset Type | Status | Count | Notes |
|------------|--------|-------|-------|
| **App Icon** | 🔄 In Progress | 1/16 | Script created, needs manual refinement |
| **Screenshots** | 📝 Planned | 0/24 | Guides complete, capture pending |
| **Preview Video** | 📝 Planned | 0/1 | Storyboard complete, production pending |
| **Copy** | ✅ Complete | 3/3 | Promo text, description, keywords ready |
| **Infrastructure** | ✅ Complete | 2/2 | Fastfile + scripts |

**Overall Progress**: ~50% (documentation complete, asset production pending)

---

## Next Steps

1. ✅ Complete all documentation
2. ⏳ Create glass morphism app icon (use script + manual refinement)
3. ⏳ Capture all 24 screenshots (follow device guides)
4. ⏳ Produce 30-second preview video (follow storyboard)
5. ⏳ Validate all assets with `validate_app_store_assets.py`
6. ⏳ Upload to App Store Connect via fastlane
7. ⏳ Submit for review

---

**Last Updated**: 2026-01-06
**Maintained By**: LexiconFlow Team
