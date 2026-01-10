# Audio Session Management Guide

## Overview
This document explains the audio session lifecycle management in Lexicon Flow, which prevents AVAudioSession error 4099 during iOS app lifecycle transitions.

## Why Audio Session Management Matters

### The Problem: AVAudioSession Error 4099

When iOS apps background, the system automatically deactivates audio sessions. Without explicit cleanup:
```
Error Domain=AVFoundationErrorDomain Code=-11859 "The operation couldn't be completed."
UserInfo={AVErrorRecordingFailureKey=Error Domain=AVFoundationErrorDomain Code=-11899 ...}
```

This error occurs when:
- App backgrounds without deactivating audio session
- System terminates app during shutdown sequence
- TTS attempts to speak with invalid session

### The Solution

```swift
// LexiconFlowApp.swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    switch newPhase {
    case .background:
        SpeechService.shared.cleanup()
    case .active:
        if oldPhase == .background || oldPhase == .inactive {
            SpeechService.shared.restartEngine()
        }
    default:
        break
    }
}
```

## Implementation

### SpeechService Methods

#### `cleanup()`
Deactivates the audio session when app backgrounds.

**Behavior:**
- Stops any ongoing speech before deactivating
- Sets `AVAudioSession.setActive(false)`
- Resets `isAudioSessionConfigured` flag

**When to Call:**
- In `LexiconFlowApp.onChange(of: scenePhase)` for `.background` case

#### `restartEngine()`
Reactivates the audio session when app returns to foreground.

**Behavior:**
- Calls `configureAudioSession()` if not already configured
- Restores audio session for TTS playback

**When to Call:**
- In `LexiconFlowApp.onChange(of: scenePhase)` for `.active` case

#### `configureAudioSession()` (private)
Initial audio session configuration.

**Configuration:**
- Category: `.playback`
- Mode: `.spokenAudio`
- Options: `.duckOthers`

## Best Practices

1. **Always deactivate before app backgrounds**
2. **Check `isAudioSessionConfigured` flag** before configuring
3. **Stop speech before deactivating** session
4. **Handle errors gracefully** with Analytics tracking

## Troubleshooting

### Common Issues

**TTS stops working after backgrounding:**
- Verify `restartEngine()` is called in `.active` case
- Check `isAudioSessionConfigured` flag state

**Audio session errors in console:**
- Check Analytics for `speech_audio_session_deactivate_failed` events
- Verify AVAudioSession category/mode configuration

### Debug Logging

Enable OSLog debugging:
```swift
#if DEBUG
let logger = Logger(subsystem: "com.lexiconflow.audio", category: "Session")
logger.debug("Audio session configured: \(configured)")
#endif
```

## Future Audio Features

When adding new audio features:
1. Share the existing `AVAudioSession` instance
2. Respect the `.duckOthers` option
3. Call `cleanup()` before background
4. Test background/foreground transitions

## Related Documentation

- `CLAUDE.md` Pattern #20: Audio Session Lifecycle Pattern
- `docs/ARCHITECTURE.md` Audio System section
- `SpeechServiceAudioSessionTests.swift` (29 tests)
