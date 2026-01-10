# Instruments Profiling Guide - LexiconFlow iOS

**Date:** 2026-01-10
**Purpose:** Validate 12 performance optimizations with Xcode Instruments
**Status:** Test infrastructure ready, awaiting manual profiling

---

## What Has Been Prepared

✅ **GlassPerformanceTest view** created at `LexiconFlow/DebugTools/GlassPerformanceTest.swift`
✅ **Developer section** added to SettingsView (DEBUG builds only)
✅ **All ModelContainer API issues** fixed for Swift 6 compatibility
✅ **Performance validation report** template ready at `docs/PERFORMANCE_VALIDATION_REPORT.md`
✅ **Detailed profiling procedures** documented in plan file

---

## Quick Start: 4 Profiling Procedures

### Option 1: Use the Performance Test View (Recommended for Procedure 3)

1. Build app in **Release** configuration (important for accurate performance)
2. Navigate to **Settings → Developer → Performance Tests**
3. Follow Xcode Instruments profiling steps below

---

## Procedure 1: DataImporter Performance (Time Profiler)

**Goal:** Validate 1000-card import <5 seconds

### Steps

1. **Launch Instruments**
   - Open `LexiconFlow.xcodeproj` in Xcode
   - **Product → Profile** (Cmd+I)
   - Select **Time Profiler** template
   - Click **Choose**

2. **Configure Target**
   - Target: **LexiconFlow** app
   - Device: **iPhone 17 Pro Simulator** (iOS 26.2)
   - Build Configuration: **Release** (critical!)

3. **Start Recording**
   - Click red **Record** button
   - App will launch in Instruments

4. **Trigger Import**
   - Navigate to **Settings → Developer → Import Test Data**
   - Import 1000 cards (use IELTS vocabulary file)

5. **Stop Recording**
   - Click **Stop** after import completes
   - Save: **File → Export** → `DataImporter_1000cards.trace`

6. **Analyze Call Tree**
   - Select **Call Tree** in left panel
   - Check filters:
     - ✓ **Hide System Libraries**
     - ✓ **Invert Call Tree**
     - ✓ **Separate by Thread**
   - Find `DataImporter.importBatch()`

7. **Document Results**
   - Import time: _____ seconds (target: <5s)
   - Fetch count: _____ calls (target: 2-3)
   - Screenshot call tree

---

## Procedure 2: Scheduler Deck Statistics (Time Profiler)

**Goal:** Validate 10-deck load <100ms

### Steps

1. **Prepare Test Data**
   - Create 10 decks with 20 cards each (via app UI)

2. **Launch Instruments**
   - **Product → Profile** → **Time Profiler**

3. **Start Recording**
   - Click **Record**
   - Navigate to deck list

4. **Trigger Operation**
   - Open deck list (triggers `Scheduler.fetchDeckStatistics()`)

5. **Stop Recording**
   - Click **Stop** after deck list renders
   - Save: `Scheduler_10decks.trace`

6. **Analyze Call Tree**
   - Filter for: `fetchDeckStatistics`
   - Check fetch count

7. **Document Results**
   - Total time: _____ ms (target: <100ms)
   - Fetch calls: _____ (target: 1 per deck)

---

## Procedure 3: GlassEffectModifier GPU Performance (Core Animation)

**Goal:** Validate 60fps with 50 glass cards

### Steps

1. **Launch Instruments**
   - **Product → Profile** → **Core Animation**

2. **Navigate to Test View**
   - In app: **Settings → Developer → Performance Tests**
   - Shows 50 glass cards for testing

3. **Start Recording**
   - Click **Record**

4. **Trigger Operation**
   - Scroll smoothly through all 50 cards
   - Keep finger on screen during scroll
   - Scroll up and down 2-3 times

5. **Stop Recording**
   - Click **Stop**
   - Save: `GlassEffect_50cards.trace`

6. **Analyze Results**
   - **FPS** graph: Should be ~60 (green bars)
   - **Frame Time**: Should be <16.6ms
   - **GPU Utilization**: Check reduction

7. **Document Results**
   - Average FPS: _____ fps (target: 60)
   - Worst frame time: _____ ms (target: <16.6ms)
   - Screenshot FPS graph

---

## Procedure 4: ImageCache Effectiveness (Allocations)

**Goal:** Validate >90% cache hit rate

### Steps

1. **Launch Instruments**
   - **Product → Profile** → **Allocations**

2. **Start Recording**
   - Click **Record**
   - Navigate to card list with images

3. **Mark Heap (Baseline)**
   - Click **Mark Heap**
   - Label: "Baseline - no images"

4. **First Pass (Cache Misses)**
   - Scroll through 100 cards with images
   - All images should load (cache misses)
   - Count: **Allocations List** → Filter: `UIImage` (~100 allocations)

5. **Mark Heap**
   - Click **Mark Heap**
   - Label: "After first 100 images"

6. **Second Pass (Cache Hits)**
   - Scroll back through same 100 cards
   - Images should load from cache
   - Check: 0 new UIImage allocations

7. **Stop Recording**
   - Click **Stop**
   - Save: `ImageCache_100images.trace`

8. **Analyze Results**
   - Compare snapshots
   - Calculate cache hit rate

9. **Document Results**
   - Cache hit rate: _____% (target: >90%)
   - Memory usage: _____ MB

---

## Expected Results Summary

| Optimization | Target | Validation Method |
|--------------|--------|-------------------|
| DataImporter | <5s | Time Profiler call tree |
| Scheduler | <100ms | Time Profiler call tree |
| GlassEffectModifier | 60fps | Core Animation FPS |
| ImageCache | >90% hit rate | Allocations heap snapshots |

---

## After Profiling: Update Documentation

1. **Update `docs/PERFORMANCE_VALIDATION_REPORT.md`**
   - Replace targets with actual measured values
   - Add Instruments trace screenshots
   - Document any deviations from targets

2. **Save Trace Files**
   - `DataImporter_1000cards.trace`
   - `Scheduler_10decks.trace`
   - `GlassEffect_50cards.trace`
   - `ImageCache_100images.trace`

3. **Report Summary**
   ```
   Completed Instruments profiling for LexiconFlow iOS performance optimizations.

   Results:
   - DataImporter: _____ seconds (target: <5s) [✅/❌]
   - Scheduler: _____ ms (target: <100ms) [✅/❌]
   - GlassEffectModifier: _____ fps (target: 60fps) [✅/❌]
   - ImageCache: _____% hit rate (target: >90%) [✅/❌]

   Trace files saved to: [path]
   Report updated: docs/PERFORMANCE_VALIDATION_REPORT.md
   ```

---

## Troubleshooting

### Build Errors
If you see ModelContainer API errors:
```swift
// ❌ WRONG: Cannot pass array to variadic parameter
ModelContainer(for: [], configurations: [config])

// ✅ CORRECT: Pass individual types
ModelContainer(for: EmptyModel.self, configurations: config)
```

### Test View Not Showing
- Ensure DEBUG build configuration
- Clean build folder: **Product → Clean Build Folder** (Cmd+Shift+K)
- Rebuild and navigate to Settings → Developer

### Instruments Not Recording
- Check Xcode → Preferences → Locations → Command Line Tools
- Ensure device is selected in Instruments
- Try restarting Xcode

---

## Next Steps

After completing Instruments profiling:

1. ✅ Document all measured results
2. ✅ Update PERFORMANCE_VALIDATION_REPORT.md with actual values
3. ✅ Save trace files for future reference
4. ✅ Create pull request with validation evidence

---

**Prepared by:** Claude Code
**Date:** 2026-01-10
**Plan File:** `/Users/fedirsaienko/.claude/plans/temporal-swimming-naur.md`
