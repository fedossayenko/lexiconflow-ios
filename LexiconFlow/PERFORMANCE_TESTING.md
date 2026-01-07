# Performance Testing Guide

## Overview
This guide provides instructions for manually running and verifying performance tests for the statistics dashboard with large datasets.

## Test Suite: PerformanceTests.swift

**Location:** `LexiconFlow/LexiconFlowTests/PerformanceTests.swift`

### Test Categories

1. **ViewModel Performance Tests**
   - `viewModelRefreshPerformance` - Tests refresh with 1000 cards
   - `viewModelRefreshVeryLargeDataset` - Tests refresh with 5000 cards

2. **StatisticsService Performance Tests**
   - `retentionRatePerformance` - Tests calculateRetentionRate with 1000 reviews
   - `studyStreakPerformance` - Tests calculateStudyStreak with 90 days of history
   - `fsrsMetricsPerformance` - Tests calculateFSRSMetrics with 1000 cards

3. **Time Range Filtering Performance**
   - `timeRangeFilteringPerformance` - Tests 7d, 30d, and all time ranges

4. **Aggregation Performance Tests**
   - `aggregationPerformance` - Tests aggregateDailyStats with 1000 sessions

5. **Concurrent Access Performance**
   - `concurrentRefreshPerformance` - Tests 5 concurrent refresh calls

6. **Memory Pressure Tests**
   - `memoryLeakTest` - Tests 10 consecutive refreshes for memory leaks

7. **Chart Data Performance**
   - `trendChartDataPerformance` - Tests trend chart with 90 data points
   - `calendarHeatmapPerformance` - Tests calendar heatmap with 90 days

8. **Integration Performance Test**
   - `fullDashboardWorkflowPerformance` - Tests complete user workflow

## Performance Thresholds

| Metric | Threshold | Notes |
|--------|-----------|-------|
| ViewModel refresh (1000 cards) | <500ms | Main acceptance criteria |
| ViewModel refresh (5000 cards) | <1000ms | Stress test threshold |
| StatisticsService calculations | <100ms each | Individual service methods |
| DailyStats aggregation | <1000ms | Background task performance |
| Full workflow | <2000ms | Complete user journey |

## Running the Tests

### Prerequisites
- macOS with Xcode installed
- iOS Simulator (iPhone 17, iOS 26.2) or physical device
- Sufficient system resources (tests create large datasets)

### Command Line

```bash
cd LexiconFlow

# Run all performance tests
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests/PerformanceTests \
  -parallel-testing-enabled NO

# Run specific test
xcodebuild test \
  -project LexiconFlow.xcodeproj \
  -scheme LexiconFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:LexiconFlowTests/PerformanceTests/viewModelRefreshPerformance \
  -parallel-testing-enabled NO
```

### Xcode IDE

1. Open `LexiconFlow.xcodeproj`
2. Select the PerformanceTests test suite in Test Navigator
3. Click the play button or press Cmd+U to run
4. View results in Test Navigator with timing information

## Understanding Test Results

### Success Criteria
- All tests pass (#expect assertions succeed)
- Execution times stay within thresholds
- No memory leaks detected
- No crashes or hangs

### Test Output
Tests use OSLog for diagnostics. View logs in Console.app or Xcode console:

```
[com.lexiconflow.tests] Performance: Created large dataset:
- 1000 flashcards
- 45 study sessions
- 892 reviews
- 90 days of history

[com.lexiconflow.tests] Performance: ViewModel refresh completed in 234.5ms
```

### CI Environment
Performance tests are **disabled in CI** by default using `.enabled(if:)`:
```swift
@Test("...", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
```

This prevents CI flakiness due to variable resource availability.

## Test Data Generation

The `createLargeDataset()` helper generates realistic test data:

- **Flashcards**: Varied FSRS states (stability, difficulty, retrievability)
- **Study Sessions**: Random distribution over 90 days with 30% activity rate
- **Reviews**: Linked to sessions and cards with varied ratings (1-4)
- **Time Distribution**: Realistic patterns with gaps and streaks

Example output:
```
Created large dataset:
- 1000 flashcards
- 45 study sessions
- 892 reviews
- 90 days of history
```

## Performance Optimization Tips

If tests fail thresholds:

1. **Check Data Model Indexes**
   - Ensure FSRSState.lastReviewDate is indexed
   - Verify FlashcardReview.reviewDate has index

2. **Review Query Predicates**
   - Check #Predicate complexity in StatisticsService
   - Look for N+1 query problems

3. **Optimize DTO Construction**
   - Review RetentionRateData, StudyStreakData, FSRSMetricsData
   - Ensure no unnecessary data transformation

4. **Test on Physical Device**
   - Simulator performance may not reflect real device
   - Run on actual device for accurate results

## Regression Testing

Track performance over time by comparing results:

```bash
# Run tests and save output
xcodebuild test ... | tee performance_test_results.txt

# Extract timing information
grep "completed in" performance_test_results.txt
```

Create performance baselines for:
- New development machines
- Different Xcode versions
- Physical device models

## Troubleshooting

### Tests timeout
- Reduce dataset size in test parameters
- Check simulator/device resources
- Verify no infinite loops in data generation

### Flaky timings
- Close other apps to reduce system load
- Run tests multiple times and average results
- Check for thermal throttling on Mac

### Memory issues
- Verify context.clearAll() is called before each test
- Check for retain cycles in test helpers
- Monitor memory usage in Instruments

## Continuous Monitoring

Consider adding these tests to:
1. **Pre-release checklist** - Must pass before App Store submission
2. **Weekly performance reports** - Track trends over time
3. **Post-refactor validation** - Ensure optimizations don't regress

## Related Documentation

- **StatisticsService**: `LexiconFlow/Services/StatisticsService.swift`
- **StatisticsViewModel**: `LexiconFlow/ViewModels/StatisticsViewModel.swift`
- **Dashboard Views**: `LexiconFlow/Views/Statistics/*.swift`

## Questions or Issues?

If tests consistently fail or results are unclear:
1. Check Xcode version and iOS SDK compatibility
2. Verify simulator/device specifications
3. Review test data generation for edge cases
4. Consult build-progress.txt for recent changes
