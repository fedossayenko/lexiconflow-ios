# TTS Timing Migration Guide

## What Changed

**Before (Version < X.X):**
- Toggle: "Auto-Play on Flip"
- Setting: `AppSettings.ttsAutoPlayOnFlip` (boolean)

**After (Version >= X.X):**
- Picker: "Pronunciation Timing"
- Setting: `AppSettings.TTSTiming` (enum with 3 cases)

## New Options Explained

### On View (New Default)
Plays pronunciation when card front appears.

**Best for:**
- Preview mode
- Quick reviews
- Learning new vocabulary

**Behavior:**
- Auto-plays when card appears
- Re-plays when returning to front (isFlipped = false)
- Manual button still available

### On Flip (Legacy Behavior)
Plays pronunciation when card flips to back.

**Best for:**
- Focused study
- Reading definition
- Previous "Auto-Play on Flip" users

**Behavior:**
- Plays only when flipping to back
- Does not auto-play on front
- Manual button still available

### Manual Only
Plays pronunciation only via speaker button.

**Best for:**
- Quiet environments
- Selective listening
- Study sessions without audio

**Behavior:**
- No auto-play
- Speaker button required
- Full control

## Migration Details

### Automatic Migration

Migration happens automatically on first app launch:
- **Old "On"** → New "On Flip" (preserves behavior)
- **Old "Off"** → New "On View" (new default experience)

### Migration Key

`UserDefaults` key: `ttsTimingMigrated`
- Prevents re-migration on subsequent launches
- Migration is one-time and idempotent

## How to Change Timing

1. Open **Settings → Text-to-Speech**
2. Tap **"Pronunciation Timing"**
3. Select preferred option:
   - 📺 Play when card front appears
   - 🔄 Play when card flips to back
   - 🎤 Play only via speaker button

## FAQ

**Q: Why did you change this?**
A: More flexibility for different study styles. The new options accommodate preview learning, focused study, and silent review.

**Q: Can I go back to old behavior?**
A: Yes! Select "On Flip" to restore the previous "Auto-Play on Flip" behavior.

**Q: Will this reset my other settings?**
A: No, only the pronunciation timing preference changes.

**Q: What if I don't want auto-play at all?**
A: Select "Manual Only" or disable TTS entirely.

**Q: Does timing affect manual speaker button?**
A: No, the speaker button works independently of timing settings.

## Technical Details

For developers, see `CLAUDE.md` Pattern #21: TTS Timing Options Pattern.

## Implementation

```swift
// TTSSettingsView.swift
private func migrateTTSTiming() {
    let migrationKey = "ttsTimingMigrated"
    guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

    if AppSettings.ttsAutoPlayOnFlip {
        AppSettings.ttsTiming = .onFlip
    } else {
        AppSettings.ttsTiming = .onView // New default
    }

    UserDefaults.standard.set(true, forKey: migrationKey)
}
```

## Related Documentation

- `CLAUDE.md` Pattern #21: TTS Timing Options Pattern
- `docs/ARCHITECTURE.md` TTS Timing Configuration section
- `TTSSettingsViewTests.swift` (24 tests for migration and timing logic)
