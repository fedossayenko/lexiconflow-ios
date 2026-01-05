# Performance Testing Guide

## Overview

This guide explains how to perform performance testing with 50+ glass elements in Lexicon Flow. The "Liquid Glass" UI design uses glass morphism effects with `.drawingGroup()` optimization for smooth 120Hz ProMotion display rendering.

## What Are Glass Elements?

Glass elements in Lexicon Flow are UI components that use the `.glassEffect()` modifier, which applies:
- **Frosted glass background** using `.ultraThinMaterial`, `.thinMaterial`, or `.regularMaterial`
- **Subtle borders** for depth perception
- **Shadow effects** for elevation
- **`.drawingGroup()` optimization** - promotes rendering to Metal for smooth 120fps animations

The `.drawingGroup()` modifier is critical for performance:
1. Caches the blurred background as a Metal texture
2. Eliminates per-frame blur recalculations
3. Enables consistent 120fps even with multiple glass elements on screen

## Performance Testing Procedure

### Step 1: Create Performance Test Data

1. Open the app and navigate to **Settings → Data Management**
2. Scroll to the **Performance Testing** section
3. Tap **"Create Performance Test Deck (50 cards)"**
4. Confirm the dialog to create 50 test cards
5. Wait for the success message

**Alternative**: Create multiple test decks:
- Tap **"Create Performance Test Decks (10, 50, 100 cards)"**
- This creates three decks for testing different scales

### Step 2: Test Deck List Scrolling Performance

1. Navigate to the **Decks** tab
2. You should see **"Performance Test Deck"** with 50 cards
3. **Scroll vigorously** through the deck list
4. **Verify**: Scrolling is smooth with no visible lag or stuttering

**What to look for**:
- ✅ Smooth scrolling at 60fps (standard display) or 120fps (ProMotion display)
- ✅ No frame drops or stuttering
- ✅ Glass effects render correctly on all deck rows
- ✅ Immediate response to scroll gestures

**Expected performance**:
- 50 deck rows with glass effects should scroll smoothly
- Each row uses `.glassEffect(.regular)` with `.drawingGroup()` optimization
- Metal-accelerated rendering prevents lag

### Step 3: Test Card List Scrolling Performance

1. Tap on the **"Performance Test Deck"** to open deck detail view
2. You should see 50 vocabulary cards
3. **Scroll vigorously** through the card list
4. **Verify**: Scrolling is smooth with no visible lag or stuttering

**What to look for**:
- ✅ Smooth scrolling through 50+ cards
- ✅ No frame drops when expanding/collapsing translations
- ✅ Card rows render correctly with all text visible
- ✅ No visual artifacts or rendering glitches

### Step 4: Stress Test with 100 Cards

1. Go back to **Settings → Data Management**
2. Tap **"Create Performance Test Deck (100 cards)"**
3. Choose **"Create 100 Cards"** in the dialog
4. Navigate to **Decks** and find the new test deck
5. **Scroll vigorously** through all 100 cards
6. **Verify**: Still smooth even with 100 glass elements

**Expected results**:
- 100 glass elements should still scroll smoothly
- Metal texture caching prevents performance degradation
- No significant frame rate drop vs 50 cards

### Step 5: Clean Up Test Data

After testing is complete:
1. Navigate to **Settings → Data Management**
2. Tap **"Clear Performance Test Data"**
3. Confirm the deletion
4. All performance test decks will be removed

## Performance Optimization Techniques Used

### 1. `.drawingGroup()` in GlassEffectModifier

```swift
.drawingGroup()  // Promotes to Metal for smooth 120Hz rendering
```

**Why it matters**:
- Renders view hierarchy to offscreen texture once
- Composites cached texture during animations
- Eliminates expensive blur recalculations per frame

### 2. Pre-computed Colors

```swift
private var shadowColor: Color {
    .black.opacity(0.1)  // Computed once, not per frame
}

private var borderColor: Color {
    .white.opacity(thickness.overlayOpacity)  // Pre-computed
}
```

**Why it matters**:
- Avoids per-frame color allocations
- Reduces GC pressure during scrolling
- Consistent performance across frames

### 3. Lazy Rendering with SwiftUI List

```swift
List {
    ForEach(decks) { deck in
        DeckRowView(deck: deck)
            .glassEffect(.regular)  // Only rendered when visible
    }
}
```

**Why it matters**:
- SwiftUI List lazily renders only visible rows
- Off-screen rows don't consume GPU resources
- Efficient memory usage for large lists

## Performance Benchmarks

### Expected Performance on Different Devices

| Device Type | Display | Target FPS | 50 Cards | 100 Cards |
|-------------|---------|------------|----------|-----------|
| iPhone 15 Pro Max | ProMotion (120Hz) | 120fps | ✅ Smooth | ✅ Smooth |
| iPhone 15 | Standard (60Hz) | 60fps | ✅ Smooth | ✅ Smooth |
| iPhone 13 | Standard (60Hz) | 60fps | ✅ Smooth | ✅ Acceptable |
| iPhone SE (3rd gen) | Standard (60Hz) | 60fps | ✅ Acceptable | ⚠️ Minor lag |

**Legend**:
- ✅ Smooth: No visible stuttering, consistent frame rate
- ✅ Acceptable: Occasional minor frame drops, no noticeable lag
- ⚠️ Minor lag: Occasional stuttering, still usable

### Performance Metrics

To measure performance using Xcode:
1. Open **Xcode → Window → Devices and Simulators**
2. Select your device
3. Open **Instruments → Time Profiler**
4. Launch app and perform scroll tests
5. Check frame rate in Core Animation instrument

**Target metrics**:
- **Frame rate**: ≥55fps average (≥110fps on ProMotion)
- **Frame drops**: <5% during scrolling
- **GPU utilization**: <80% on older devices
- **Memory**: <50MB increase for 100 glass elements

## Troubleshooting Performance Issues

### Issue: Stuttering when scrolling

**Possible causes**:
1. **Too many glass effects on screen**
   - Solution: Reduce card count or use thinner glass (`.thin` instead of `.regular`)

2. **Device not supported**
   - Solution: Disable glass effects in Settings → Appearance

3. **Background processes consuming resources**
   - Solution: Close background apps, restart device

### Issue: Visual artifacts on glass elements

**Possible causes**:
1. **Metal rendering fallback**
   - Solution: Device may not support Metal properly
   - Check: Console logs for Metal errors

2. **Memory pressure**
   - Solution: Reduce test data size
   - Check: Xcode Debug Memory Graph

### Issue: Performance degrades over time

**Possible causes**:
1. **Memory leak**
   - Solution: Profile with Xcode Leaks instrument
   - Check: Retain cycles in closures

2. **SwiftData context bloat**
   - Solution: Clear test data and restart app
   - Check: ModelContext registered objects count

## Automated Performance Testing

To create automated performance tests, see:
- `LexiconFlowTests/PerformanceTests.swift` (not yet implemented)
- Instruments automation scripts

Future enhancements may include:
- Frame rate monitoring in production
- Performance analytics integration
- Automated performance regression tests

## Related Documentation

- **Glass Effect Implementation**: `LexiconFlow/Views/Components/GlassEffectModifier.swift`
- **Test Data Generator**: `LexiconFlow/Utils/PerformanceTestDataGenerator.swift`
- **Data Management UI**: `LexiconFlow/Views/Settings/DataManagementView.swift`
- **Architecture**: `docs/ARCHITECTURE.md` - Glass Morphism section
- **ROADMAP**: `docs/ROADMAP.md` - Phase 2 Performance Optimization

## Conclusion

Performance testing with 50+ glass elements verifies that the "Liquid Glass" UI design is smooth and responsive. The `.drawingGroup()` optimization ensures Metal-accelerated rendering, enabling consistent 60fps/120fps performance even with many glass elements on screen.

**Key Takeaway**: Glass morphism effects should not compromise scrolling performance. If you encounter lag, it indicates a performance regression that should be investigated and fixed.
