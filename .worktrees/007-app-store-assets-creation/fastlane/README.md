# Fastlane Directory

## Purpose

This directory contains all App Store assets ready for upload to App Store Connect via fastlane automation or manual submission.

---

## Directory Structure

```
fastlane/
  ├── README.md (this file)
  ├── screenshots/
  │   ├── iphone_se/         # 6 screenshots @ 640x1136
  │   ├── iphone_15/         # 6 screenshots @ 1290x2796
  │   ├── iphone_15_pro_max/ # 6 screenshots @ 1320x2868
  │   └── ipad/              # 6 screenshots @ 2732x2048
  └── video/
      ├── README.md
      ├── raw_footage/       # Original screen recordings (.gitignore'd)
      ├── project_files/     # Editing project files
      └── exports/           # Final rendered videos (.gitignore'd)
```

---

## Screenshots

### Narrative Flow (6 Screens)

1. **Welcome** - Hook with value proposition
2. **FSRS Algorithm** - Establish scientific credibility
3. **Deck Management** - Show organization capabilities
4. **Liquid Glass Study** - HERO screenshot showcasing differentiator
5. **Smart Rating** - Show algorithm in action
6. **Study Modes** - Demonstrate user agency

### Device Specifications

| Device | Resolution | Display | Caption Height | Font Size |
|--------|------------|---------|----------------|-----------|
| iPhone SE | 640x1136 | 4.7" | 80px | 20pt |
| iPhone 15 | 1290x2796 | 6.1" | 100px | 26pt |
| iPhone 15 Pro Max | 1320x2868 | 6.7" | 110px | 28pt |
| iPad Pro 12.9" | 2732x2048 | 12.9" | 140px | 36pt |

### File Naming

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

### Upload Instructions

**Option 1: Manual Upload**
1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to App Information → Screenshots
3. Drag screenshots to each device slot
4. Click Save

**Option 2: Fastlane Automation**
```bash
# Install fastlane
gem install fastlane

# Upload screenshots
fastlane upload_screenshots

# Or use Fastfile lane
fastlane upload_app_store_assets
```

---

## Video

### Scene Breakdown

| Scene | Duration | Content | Source |
|-------|----------|---------|--------|
| 1 | 0:00-0:05 | Problem graphic | Motion graphic |
| 2 | 0:05-0:10 | Welcome onboarding | Screen recording |
| 3 | 0:10-0:15 | FSRS algorithm | Screen recording |
| 4 | 0:15-0:20 | Liquid Glass HERO | Screen recording ⭐ |
| 5 | 0:20-0:25 | Study modes | Screen recording |
| 6 | 0:25-0:30 | CTA graphic | Motion graphic |

### Specifications

- **Resolution**: 1920x1080 (1080p)
- **Frame Rate**: 30 FPS
- **Format**: M4V or MOV
- **Duration**: 27-30 seconds
- **File Size**: < 50 MB

### Upload Instructions

**Manual Upload Only** (fastlane doesn't support video upload):
1. Log in to App Store Connect
2. Navigate to App Information → App Preview
3. Drag video file to upload area
4. Wait for processing
5. Click Save

---

## Automation (Optional)

### Fastfile Template

```ruby
# fastlane/Fastfile

platform :ios do
  desc "Upload screenshots to App Store Connect"
  lane :upload_screenshots do
    upload_to_app_store(
      screenshots_path: "./fastlane/screenshots",
      skip_binary_upload: true,
      skip_metadata: true,
      skip_screenshots: false
    )
  end

  desc "Upload App Store metadata (promotional text, description, keywords)"
  lane :upload_metadata do
    upload_to_app_store(
      skip_binary_upload: true,
      skip_screenshots: true,
      skip_metadata: false
    )
  end

  desc "Upload all App Store assets"
  lane :upload_app_store_assets do
    upload_screenshots
    upload_metadata
  end
end
```

### Installation

```bash
# Initialize fastlane
cd /path/to/LexiconFlow
fastlane init

# Install dependencies
bundle install

# Run upload lane
fastlane upload_app_store_assets
```

---

## Asset Verification

Before uploading, verify:

### Screenshots
- [ ] 6 screenshots per device (24 total)
- [ ] Correct resolutions for each device
- [ ] Captions are legible
- [ ] Glass morphism effects visible
- [ ] No UI glitches or artifacts
- [ ] File size < 500KB each

### Video
- [ ] Duration: 27-30 seconds
- [ ] Resolution: 1920x1080
- [ ] Format: M4V or MOV
- [ ] File size: < 50 MB
- [ ] All 6 scenes present
- [ ] Text overlays added
- [ ] Audio level appropriate

---

## .gitignore

The following directories are excluded from Git:

```
fastlane/video/raw_footage/
fastlane/video/exports/
*.mp4
*.mov
*.m4v
```

**Reason**: Video files are too large for Git (hundreds of MB to GB). Store them locally or use cloud storage (Google Drive, Dropbox, etc.).

---

## Troubleshooting

### Screenshots Not Uploading

**Problem**: fastlane can't find screenshots
**Solution**:
- Verify directory structure matches expected layout
- Check file names match pattern: `{Number}_{Title}_{Width}x{Height}.png`
- Ensure 6 screenshots per device

### Wrong Resolution

**Problem**: Screenshots rejected for incorrect resolution
**Solution**:
- Run `python3 scripts/validate_app_store_assets.py`
- Check resolution with: `file {screenshot.png}` or `mdls {screenshot.png}`
- Re-process with `scripts/process_screenshots.py`

### Video Processing Failed

**Problem**: Video won't upload or is rejected
**Solution**:
- Verify duration < 30 seconds
- Check file size < 50 MB
- Ensure format is M4V or MOV
- Test playback on iPhone/iPad

---

## Related Documentation

**Screenshot Capture**:
- `docs/screenshots-plan.md` (Overall strategy)
- `docs/iphone-se-screenshot-guide.md`
- `docs/iphone-15-screenshot-guide.md`
- `docs/iphone-15-pro-max-screenshot-guide.md`
- `docs/ipad-screenshot-guide.md`
- `docs/test-data-setup-guide.md`

**Screenshot Processing**:
- `scripts/process_screenshots.py` (Automated processing)

**Video Production**:
- `docs/app-store-preview-video-storyboard.md`
- `docs/app-store-video-recording-guide.md`
- `docs/app-store-video-editing-guide.md`

**App Store Copy**:
- `docs/app-store-copy.md` (Promotional text, description, keywords)

---

## Maintenance

### When to Update

Update assets when:
- App UI changes significantly
- New features added to showcase
- Screenshots look outdated
- A/B testing shows better alternatives

### Version Control

Track asset versions in `implementation_plan.json`:
- Document when assets were created
- Note which version of app they represent
- Track A/B test results

---

**Last Updated**: 2026-01-06
**Status**: Infrastructure complete, ready for manual asset creation and submission
