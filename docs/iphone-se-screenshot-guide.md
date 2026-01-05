# iPhone SE Screenshot Capture Guide

**Device**: iPhone SE (3rd generation)
**Screen Size**: 4.7"
**Resolution**: 750×1334 (@2x)
**Screenshots Required**: 6

---

## Simulator Setup

### Launch iPhone SE Simulator

```bash
# Boot iPhone SE simulator
xcrun simctl boot "iPhone SE (3rd generation)"

# Open Simulator app
open -a Simulator
```

### Verify Display Settings

1. Open Simulator → **Features → Toggle Status Bar**
2. Ensure status bar is visible (shows time, battery)
3. Set display zoom to **Standard** (not Zoomed)

---

## Screenshot 1: "Forget Less" (Home Screen)

### Scene Description
- Home screen showing today's due cards
- Study streak indicator
- Quick stats bar

### Setup Steps

1. **Launch App**
   - Build and run in Xcode (`Cmd+R`)
   - Wait for home screen to load

2. **Verify Due Cards**
   - Ensure 25-30 cards are due
   - Show study streak (7+ days)

3. **Navigate**
   - Be on main/home screen
   - No modals or sheets visible

4. **Capture**
   - Press `Cmd+S` in Simulator
   - Save as: `screenshots_raw/iphone_se/1_home.png`

### Caption
```
"Tired of forgetting what you learn?"
```

### Post-Processing Notes
- Position: Bottom 20% of screenshot
- Font: SF Pro Text, 36pt, Semibold
- Background: Black, 60% opacity
- Padding: 20px

---

## Screenshot 2: "FSRS v5" (Algorithm Info)

### Scene Description
- Settings → About → Algorithm screen
- FSRS v5 badge/logo
- Retention rate stat (90%)

### Setup Steps

1. **Navigate to Settings**
   - Tap settings icon (gear)
   - Scroll to "About"

2. **Open Algorithm Section**
   - Tap "Algorithm" or "FSRS"
   - View algorithm details

3. **Verify Content**
   - "FSRS v5" visible
   - "90% retention" stat displayed

4. **Capture**
   - Press `Cmd+S`
   - Save as: `screenshots_raw/iphone_se/2_algorithm.png`

### Caption
```
"90% retention with FSRS v5 algorithm"
```

---

## Screenshot 3: "Liquid Glass" (Study Session)

### Scene Description
- Active study session
- Card partially flipped (shows depth)
- Glass card effect visible

### Setup Steps

1. **Start Study Session**
   - Tap "Study Now" on home screen
   - Wait for first card to appear

2. **Trigger Card Flip**
   - Tap card to flip
   - Wait for flip animation to reach ~50%

3. **Pause Animation**
   - The glass effect is most visible mid-flip
   - Ensure blur and depth are visible

4. **Capture**
   - Press `Cmd+S` at the right moment
   - Save as: `screenshots_raw/iphone_se/3_study.png`

### Caption
```
"Beautiful Liquid Glass interface"
```

### Notes
- Glass card should show frosted blur
- Gradient colors visible (indigo→pink→violet)
- Depth effect clear

---

## Screenshot 4: "Study Modes" (Mode Selection)

### Scene Description
- Study mode selection screen
- All 3 modes visible with icons
- Mode descriptions

### Setup Steps

1. **Navigate to Mode Selection**
   - From home screen, tap "+" or "New Session"
   - Or access via deck menu

2. **Verify Modes Visible**
   - Flashcards mode
   - Quiz mode
   - Writing mode

3. **Ensure Clean Layout**
   - No keyboards visible
   - No alerts or modals

4. **Capture**
   - Press `Cmd+S`
   - Save as: `screenshots_raw/iphone_se/4_modes.png`

### Caption
```
"Flashcards, Quiz, and Writing modes"
```

---

## Screenshot 5: "Smart Scheduling" (Stats/Calendar)

### Scene Description
- Study statistics or calendar view
- Shows spaced repetition pattern
- Visualizes retention over time

### Setup Steps

1. **Navigate to Stats**
   - Tap stats icon (chart)
   - Or access via deck details

2. **Verify Content**
   - Calendar with study dots
   - Or retention graph
   - Or stats dashboard

3. **Ensure Data Looks Good**
   - Show 7+ days of study activity
   - Display retention rate if available

4. **Capture**
   - Press `Cmd+S`
   - Save as: `screenshots_raw/iphone_se/5_stats.png`

### Caption
```
"Smart scheduling optimizes study time"
```

---

## Screenshot 6: "Start Learning" (Welcome/Onboarding)

### Scene Description
- Welcome back or onboarding screen
- Clear call-to-action button
- Welcoming copy

### Setup Steps

1. **Navigate to Onboarding**
   - Fresh install (delete app data if needed)
   - Or log out to see welcome screen

2. **Verify CTA**
   - "Get Started" or "Continue Learning" button visible
   - Button should be prominent

3. **Check Layout**
   - Centered content
   - Clean, uncluttered

4. **Capture**
   - Press `Cmd+S`
   - Save as: `screenshots_raw/iphone_se/6_welcome.png`

### Caption
```
"Start learning vocabulary today"
```

---

## Post-Processing

### Using the Processing Script

```bash
python3 scripts/process_screenshots.py \
  --device iphone_se \
  --input screenshots_raw/iphone_se/ \
  --output fastlane/screenshots/iphone_se/ \
  --caption-bottom \
  --frame-device
```

### Manual Processing

For each screenshot:

1. **Resize** (if needed)
   - Target: 750×1334
   - Use high-quality resampling (Lanczos)

2. **Add Caption**
   - Text: (see captions above)
   - Font: SF Pro Text, 36pt
   - Position: Bottom 20%
   - Background: Black, 60% opacity
   - Padding: 20px

3. **Verify Quality**
   - No pixelation
   - Caption legible
   - Colors accurate

4. **Save**
   - Format: PNG
   - Name: `{Number}_{Title}_{Width}x{Height}.png`
   - Example: `1_FORGET_LESS_750x1334.png`

---

## Quality Checklist

For each final screenshot:

- [ ] Resolution is exactly 750×1334
- [ ] PNG format, lossless
- [ ] No simulator chrome
- [ ] Caption is legible
- [ ] Glass morphism effect visible (Screenshot 3)
- [ ] App UI not obscured
- [ ] File size < 3 MB
- [ ] Filename follows convention

---

## Estimated Time

- **Setup**: 15 minutes (simulator, test data)
- **Capture**: 20 minutes (6 shots × 3 min each)
- **Process**: 15 minutes
- **Review**: 10 minutes

**Total**: ~1 hour

---

## Troubleshooting

### Simulator Won't Boot

```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all
```

### Screenshots Have Status Bar

- This is expected and required
- Apple expects full-screen screenshots
- Don't crop status bar

### App Data Missing

```bash
# Reset app data in simulator
# iOS Simulator → Device → Erase All Content and Settings
```

### Glass Effect Not Visible

- Ensure card is mid-flip (not front or back)
- Check that glass morphism is implemented in UI
- Verify background blur is enabled

---

## Next Steps

1. ✅ Capture all 6 screenshots
2. ✅ Process with captions
3. ✅ Review for quality
4. ✅ Move to `fastlane/screenshots/iphone_se/`
5. ➡️ Repeat for iPhone 15

---

**Related Documents**

- [Screenshots Plan](./screenshots-plan.md)
- [Test Data Setup Guide](./test-data-setup-guide.md)
- [Processing Script Usage](../scripts/process_screenshots.py)
