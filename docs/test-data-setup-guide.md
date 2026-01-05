# Test Data Setup Guide

**Purpose**: Prepare test data for capturing high-quality App Store screenshots

---

## Overview

Before capturing screenshots, the app must contain realistic test data that showcases the app's features effectively. This guide explains how to set up comprehensive test data.

---

## Test Data Requirements

### Decks

Create **3-4 decks** with different languages/topics:

1. **Spanish Vocabulary** (Primary deck)
   - 100+ cards
   - Mix of difficulty levels
   - Good for showing algorithm effectiveness

2. **Japanese Kanji** (Secondary deck)
   - 50+ cards
   - Different script (shows app versatility)

3. **GRE Words** (Tertiary deck)
   - 75+ cards
   - Advanced vocabulary (shows target audience)

4. **French Basics** (Optional)
   - 30+ cards
   - European language support

### Card States Per Deck

Each deck should have cards in various states:

| State | Count | Purpose |
|-------|-------|---------|
| **New** | 20-30 | Show learning queue |
| **Learning** | 10-15 | Show short-term learning |
| **Review** | 30-50 | Show spaced repetition |
| **Relearning** | 5-10 | Show forgotten cards |

### User Statistics

Configure user stats to look impressive:

- **Total cards**: 500-1000
- **Cards due today**: 25-30 (varies per screenshot)
- **Retention rate**: 90%+
- **Study streak**: 7+ days
- **Total study time**: 10+ hours
- **Cards learned**: 300+

---

## Manual Setup via Simulator

### Option 1: Create via App UI

**Time Required**: 2-3 hours

#### Step 1: Create Decks

1. Launch app in simulator
2. Tap "+" → "New Deck"
3. Name deck: "Spanish Vocabulary"
4. Repeat for other decks

#### Step 2: Import Cards

**Option A: Manual Entry**

Create a CSV file:

```csv
front,back,tags
Hola,Hello,greeting
Adiós,Goodbye,greeting
Gracias,Thank you,greeting
Por favor,Please,courtesy
...
```

Then import:
1. Open deck
2. Tap "+" → "Import"
3. Select CSV file
4. Confirm import

**Option B: Use Anki Import**

If you have Anki decks:
1. Export from Anki (APKG format)
2. Import in LexiconFlow
3. Review and adjust

#### Step 3: Study Cards to Create States

1. **Create New Cards**
   - Import 100+ cards
   - These will be in "New" state

2. **Create Learning Cards**
   - Study 10-15 cards once
   - Don't complete them
   - They'll be in "Learning" state

3. **Create Review Cards**
   - Study 30+ cards to completion
   - Wait for them to become due
   - Or manually set due date to today

4. **Create Relearning Cards**
   - Study some cards, then mark "Forgot"
   - They'll enter "Relearning"

#### Step 4: Adjust Statistics

Most apps allow tweaking stats via debug menu or database:

**Option A: Debug Menu (if available)**
1. Enable debug mode
2. Access "Dev → Set Stats"
3. Configure desired numbers

**Option B: Direct Database Modification**

```bash
# Access simulator container
cd ~/Library/Developer/CoreSimulator/Devices/<DEVICE_ID>/data/Containers/Data/Application/<APP_ID>/Documents

# Open SQLite database
sqlite3 lexiconflow.db

# Update stats
UPDATE user_stats SET total_cards = 500, retention_rate = 90, study_streak = 7;
```

---

### Option 2: Automated Test Data Generation

**Time Required**: 30 minutes

Create a test data generation script:

```python
# generate_test_data.py
import random
import json

# Generate cards
decks = {
    "spanish": {
        "cards": [
            {"front": "Hola", "back": "Hello", "state": "review"},
            {"front": "Adiós", "back": "Goodbye", "state": "learning"},
            # ... 100 more cards
        ]
    },
    "japanese": {
        "cards": [
            {"front": "こんにちは", "back": "Hello", "state": "new"},
            # ... 50 more cards
        ]
    }
}

# Save as JSON
with open("test_data.json", "w") as f:
    json.dump(decks, f, indent=2)
```

Then import via app's data import feature.

---

## Screenshot-Specific Data Setup

### Screenshot 1: Home Screen

**Required State**:
- Due cards: 27
- Study streak: 14 days
- Today's study time: 15 minutes

**Setup**:
1. Ensure 27 cards due across all decks
2. Set study streak to 14 days
3. Study a few cards today to generate activity

### Screenshot 2: FSRS Algorithm

**Required State**:
- FSRS version: v5
- Retention rate: 90%
- Total reviews: 500+

**Setup**:
1. Verify FSRS v5 is enabled in settings
2. Update stats to show 90% retention
3. Ensure 500+ reviews logged

### Screenshot 3: Liquid Glass UI

**Required State**:
- Active study session
- Card mid-flip
- Glass effect visible

**Setup**:
1. Start study session
2. Tap card to flip
3. Pause at ~50% flip

### Screenshot 4: Study Modes

**Required State**:
- Mode selection screen
- All 3 modes unlocked

**Setup**:
1. Navigate to mode selection
2. Ensure no mode is locked

### Screenshot 5: Smart Scheduling

**Required State**:
- Calendar with 7+ days of activity
- Retention graph visible

**Setup**:
1. Study every day for 7+ days
2. Or manually add activity records
3. Open stats/calendar view

### Screenshot 6: Welcome Screen

**Required State**:
- Fresh install OR logged out
- Clean welcome screen

**Setup**:
1. Delete app and reinstall
2. Or log out if app supports it
3. Navigate to onboarding/welcome

---

## Test Data CSV Template

### Spanish Vocabulary (100 cards)

```csv
front,back,tags,difficulty
Hola,Hello,greeting,1
Adiós,Goodbye,greeting,1
Gracias,Thank you,greeting,1
Por favor,Please,courtesy,1
De nada,You're welcome,courtesy,1
Buenos días,Good morning,greeting,1
Buenas noches,Good night,greeting,1
¿Cómo estás?,How are you?,conversation,2
Muy bien,Very good,conversation,2
Mal,Bad,conversation,2
Agua,Water,nouns,1
Casa,House,nouns,1
Perro,Dog,nouns,1
Gato,Cat,nouns,1
Comer,Eat,verbs,2
Beber,Drink,verbs,2
Dormir,Sleep,verbs,2
...
```

### Japanese Kanji (50 cards)

```csv
front,back,reading,tags
日,Day,にち,basic
月,Month,げつ,basic
火,Fire,か,nature
水,Water,すい,nature
木,Tree,もく,nature
金,Gold,きん,nature
土,Earth,ど,nature
...
```

---

## Quick Setup Script (iOS Simulator)

### Bash Script to Reset and Populate

```bash
#!/bin/bash
# setup-test-data.sh

echo "🔄 Setting up test data..."

# 1. Reset simulator app data
echo "📱 Resetting app..."
xcrun simctl spawn booted launchctl plist reset com.lexiconflow.app

# 2. Wait for app to reinstall
sleep 5

# 3. Launch app
echo "🚀 Launching app..."
xcrun simctl launch booted com.lexiconflow.app

# 4. Import test data via Xcode console
echo "📊 Importing test data..."
# Use debug console to inject data
# (This varies by app implementation)

echo "✅ Test data setup complete!"
```

---

## Verification Checklist

After setting up test data, verify:

### Decks
- [ ] 3-4 decks exist
- [ ] Each deck has 30-100 cards
- [ ] Mix of languages/topics

### Card States
- [ ] New cards present (20-30 per deck)
- [ ] Learning cards present (10-15 per deck)
- [ ] Review cards present (30-50 per deck)
- [ ] Relearning cards present (5-10 per deck)

### Statistics
- [ ] Total cards: 500+
- [ ] Cards due today: 25-30
- [ ] Retention rate: 90%+
- [ ] Study streak: 7+ days
- [ ] Total study time: 10+ hours

### Screenshot Readiness
- [ ] Screenshot 1: Home screen ready (27 due)
- [ ] Screenshot 2: FSRS info visible
- [ ] Screenshot 3: Can trigger card flip
- [ ] Screenshot 4: Mode selection accessible
- [ ] Screenshot 5: Stats/calendar populated
- [ ] Screenshot 6: Welcome screen accessible

---

## Time Estimate

| Method | Time | Difficulty |
|--------|------|------------|
| **Manual via UI** | 2-3 hours | Easy |
| **CSV Import** | 1 hour | Medium |
| **Script Generation** | 30 min | Hard (requires coding) |

**Recommended**: CSV Import (best balance of time/effort)

---

## Troubleshooting

### Cards Not Showing Up

- Force quit app and relaunch
- Check import completed successfully
- Verify deck is not empty

### Stats Not Updating

- Study some cards to trigger stat calculation
- Wait for background sync
- Check if stats cache needs clearing

### Simulator Crashes

- Reset simulator: `xcrun simctl erase all`
- Reduce test data size
- Check for memory leaks

---

## Related Documents

- [Screenshots Plan](./screenshots-plan.md)
- [iPhone SE Screenshot Guide](./iphone-se-screenshot-guide.md)
- [Processing Script](../scripts/process_screenshots.py)

---

## Next Steps

1. ✅ Set up test data using preferred method
2. ✅ Verify all data is present
3. ✅ Test navigating to all screenshot scenes
4. ➡️ Begin capturing screenshots (see device guides)

---

**Document Control**

- **Author**: QA Team
- **Status**: Approved
- **Last Updated**: 2026-01-06
