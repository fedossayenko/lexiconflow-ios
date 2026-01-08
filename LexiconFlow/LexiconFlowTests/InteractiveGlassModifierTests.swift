//
//  InteractiveGlassModifierTests.swift
//  LexiconFlowTests
//
//  Tests for reactive glass refraction effects.
//

import SwiftUI
import Testing
@testable import LexiconFlow

@Suite("InteractiveGlassModifier Tests")
struct InteractiveGlassModifierTests {
    @Test("InteractiveEffect.clear returns empty effect")
    func clearEffect() {
        let effect = InteractiveEffect.clear()
        #expect(effect.tint == .clear)
    }

    @Test("InteractiveEffect.tint creates colored effect")
    func tintEffect() {
        let effect = InteractiveEffect.tint(.green.opacity(0.3))
        #expect(effect.tint != .clear)
    }

    @Test("InteractiveEffect.tint with red color works correctly")
    func redTintEffect() {
        let effect = InteractiveEffect.tint(.red.opacity(0.5))
        #expect(effect.tint != .clear)
    }

    @Test("InteractiveEffect.tint with blue color works correctly")
    func blueTintEffect() {
        let effect = InteractiveEffect.tint(.blue.opacity(0.2))
        #expect(effect.tint != .clear)
    }
}
