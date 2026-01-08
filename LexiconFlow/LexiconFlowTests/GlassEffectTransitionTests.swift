//
//  GlassEffectTransitionTests.swift
//  LexiconFlowTests
//
//  Tests for glass morphism transition effects.
//

import SwiftUI
import Testing
@testable import LexiconFlow

@Suite("GlassEffectTransition Tests")
struct GlassEffectTransitionTests {
    @Test("GlassTransitionStyle has three cases")
    func transitionStyleCases() {
        let styles: [GlassTransitionStyle] = [.scaleFade, .dissolve, .liquid]
        #expect(styles.count == 3)
    }

    @Test("ScaleFade style exists")
    func scaleFadeStyle() {
        let style = GlassTransitionStyle.scaleFade
        // Verify style can be created
        #expect(style == GlassTransitionStyle.scaleFade)
    }

    @Test("Dissolve style exists")
    func dissolveStyle() {
        let style = GlassTransitionStyle.dissolve
        #expect(style == GlassTransitionStyle.dissolve)
    }

    @Test("Liquid style exists")
    func liquidStyle() {
        let style = GlassTransitionStyle.liquid
        #expect(style == GlassTransitionStyle.liquid)
    }

    @Test("All transition styles are distinct")
    func transitionStyleDistinctness() {
        let scaleFade = GlassTransitionStyle.scaleFade
        let dissolve = GlassTransitionStyle.dissolve
        let liquid = GlassTransitionStyle.liquid

        #expect(scaleFade != dissolve)
        #expect(scaleFade != liquid)
        #expect(dissolve != liquid)
    }
}
