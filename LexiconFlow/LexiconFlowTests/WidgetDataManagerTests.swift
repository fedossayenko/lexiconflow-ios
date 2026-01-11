//
//  WidgetDataManagerTests.swift
//  LexiconFlowTests
//
//  Tests for WidgetDataManager serialization and shared data logic.
//

import XCTest
@testable import LexiconFlow

final class WidgetDataManagerTests: XCTestCase {
    func testPayloadSerialization() throws {
        // Given
        let dueCount = 10
        let streakCount = 42
        let lastStudyDate = Date()

        let payload = WidgetPayload(
            dueCount: dueCount,
            streakCount: streakCount,
            lastStudyDate: lastStudyDate,
            updatedAt: Date()
        )

        // When
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(WidgetPayload.self, from: data)

        // Then
        XCTAssertEqual(decoded.dueCount, dueCount)
        XCTAssertEqual(decoded.streakCount, streakCount)
        // Date comparison with tolerance
        XCTAssertEqual(decoded.lastStudyDate?.timeIntervalSince1970 ?? 0, lastStudyDate.timeIntervalSince1970, accuracy: 0.001)
    }
}
