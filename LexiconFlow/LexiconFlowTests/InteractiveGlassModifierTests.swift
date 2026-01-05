//
//  InteractiveGlassModifierTests.swift
//  LexiconFlowTests
//
//  Tests for reactive glass refraction effects.
//

import Testing
import SwiftUI
@testable import LexiconFlow

@Suite("InteractiveGlassModifier Tests")
struct InteractiveGlassModifierTests {

    @Test("InteractiveEffect.clear returns empty effect")
    func testClearEffect() {
        let effect = InteractiveEffect.clear()
        #expect(effect.tint == .clear)
    }

    @Test("InteractiveEffect.tint creates colored effect")
    func testTintEffect() {
        let effect = InteractiveEffect.tint(.green.opacity(0.3))
        #expect(effect.tint != .clear)
    }

    @Test("InteractiveEffect.tint with red color works correctly")
    func testRedTintEffect() {
        let effect = InteractiveEffect.tint(.red.opacity(0.5))
        #expect(effect.tint != .clear)
    }

    @Test("InteractiveEffect.tint with blue color works correctly")
    func testBlueTintEffect() {
        let effect = InteractiveEffect.tint(.blue.opacity(0.2))
        #expect(effect.tint != .clear)
    }
}
