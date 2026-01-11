Based on the analysis of `DeckStatisticsCache.swift` in Swift 6 strict concurrency context:

### Concurrency Safety Assessment
1. **`@MainActor` isolation is sufficient**  
   The class is correctly annotated with `@MainActor`, confining all state mutations (cache/timestamp) to the main thread. This prevents data races since:
   - All properties (`cache`, `timestamp`, `ttl`) are private
   - All public methods (`get`, `set`, `invalidate`) are isolated to `@MainActor`
   - No `nonisolated` access exists

2. **DEBUG `timeProvider` is safe**  
   The static `timeProvider` in the DEBUG extension:
   - Is only used in test builds (`#if DEBUG`)
   - Accesses are confined via `@MainActor` in `currentTime()`
   - Test setup/teardown methods (`setTimeProviderForTesting`/`resetTimeProvider`) are explicitly documented for test-only use

3. **Mutable TTL in DEBUG is safe**  
   The `ttl` property:
   - Is only mutated via `@MainActor`-isolated methods (`setTTLForTesting()`)
   - Has no concurrent modification paths
   - Resets to default after tests

4. **No cross-actor mutation risks**  
   `Scheduler`'s interactions are safe because:
   - `Scheduler` is also `@MainActor`-isolated
   - Cache methods are called synchronously within same actor
   - DTOs (`DeckStatistics`) are value types (`Sendable`)

5. **`invalidate()` handles concurrency correctly**  
   - Uses actor-isolated queue for mutations
   - Atomic dictionary operations (`removeValue/removeAll`)
   - No partial state updates during invalidation

### Recommendations
1. **Enhance `timeProvider` safety**  
   Add `@MainActor` to the DEBUG extension:
   ```swift
   #if DEBUG
   @MainActor  // Add this
   extension DeckStatisticsCache { ... }
   #endif
   ```

2. **Optimize batch operations**  
   Consider using `withLock` for high-frequency batch updates (though currently safe via `@MainActor`):
   ```swift
   func setBatch(_ statistics: [UUID: DeckStatistics]) {
       MainActor.assumeIsolated {
           cache.merge(statistics) { _, new in new }
           timestamp = Self.currentTime()
       }
   }
   ```

**Conclusion**: The implementation is concurrency-safe for Swift 6 requirements. The `@MainActor` isolation effectively prevents data races while allowing controlled mutation for testing.