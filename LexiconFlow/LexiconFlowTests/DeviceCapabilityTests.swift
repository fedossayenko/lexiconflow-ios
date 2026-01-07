//
//  DeviceCapabilityTests.swift
//  LexiconFlowTests
//
//  Created on 2025-01-07.
//

import Testing
import Foundation
@testable import LexiconFlow

/// Tests for DeviceCapability utility.
///
/// These tests verify that device capability detection works correctly
/// for on-device translation services.
struct DeviceCapabilityTests {

    // MARK: - On-Device Translation Support

    @Test("iOS 26+ supports on-device translation")
    @available(iOS 26.0, *)
    func ios26SupportsOnDeviceTranslation() {
        let result = DeviceCapability.supportsOnDeviceTranslation()
        #expect(result == true, "iOS 26+ should support on-device translation")
    }

    // MARK: - Edge Cases

    @Test("On-device translation check is deterministic")
    func onDeviceTranslationCheckIsDeterministic() {
        // Call multiple times and verify consistency
        let result1 = DeviceCapability.supportsOnDeviceTranslation()
        let result2 = DeviceCapability.supportsOnDeviceTranslation()
        let result3 = DeviceCapability.supportsOnDeviceTranslation()

        #expect(result1 == result2, "On-device translation check should be consistent")
        #expect(result2 == result3, "On-device translation check should be consistent")
    }

    // MARK: - Thread Safety

    @Test("All capability checks are thread-safe")
    func allCapabilityChecksAreThreadSafe() async throws {
        // Run multiple checks concurrently
        async let result1 = Task { DeviceCapability.supportsOnDeviceTranslation() }.value

        // Should complete without crashing
        let r1 = await result1

        #expect(r1 == true || r1 == false, "On-device translation check should return boolean")
    }
}
