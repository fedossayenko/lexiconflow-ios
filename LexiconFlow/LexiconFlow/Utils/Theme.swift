//
//  Theme.swift
//  LexiconFlow
//
//  Centralized theme utilities for consistent UI across the app
//  Includes CEFR color coding, badge styles, and visual constants
//

import SwiftUI

/// Centralized theme utilities for LexiconFlow
enum Theme {
    // MARK: - CEFR Level Colors

    /// Returns the color associated with a CEFR level
    /// - Parameter level: The CEFR level string (e.g., "A1", "B2")
    /// - Returns: A SwiftUI Color representing the level
    ///
    /// **Color Mapping:**
    /// - A1/A2 (Beginner): Green - represents growth and foundation
    /// - B1/B2 (Intermediate): Blue - represents stability and depth
    /// - C1/C2 (Advanced): Purple - represents mastery and sophistication
    /// - Invalid/Unknown: Gray - represents neutrality
    static func cefrColor(for level: String) -> Color {
        switch level.uppercased() {
        case "A1", "A2": .green
        case "B1", "B2": .blue
        case "C1", "C2": .purple
        default: .gray
        }
    }

    /// Returns the background opacity for CEFR badges
    /// - Parameter level: The CEFR level string
    /// - Returns: Opacity value between 0.0 and 1.0
    ///
    /// **Opacity Mapping:**
    /// - A1/A2: 0.2 - lighter for beginner levels
    /// - B1/B2: 0.3 - medium for intermediate
    /// - C1/C2: 0.4 - darker for advanced levels
    /// - Invalid: 0.15 - minimal for unknown
    static func cefrBadgeOpacity(for level: String) -> Double {
        switch level.uppercased() {
        case "A1", "A2": 0.2
        case "B1", "B2": 0.3
        case "C1", "C2": 0.4
        default: 0.15
        }
    }

    // MARK: - Badge Styles

    /// Creates a standard CEFR badge configuration
    /// - Parameters:
    ///   - level: The CEFR level string
    ///   - style: The badge style (compact or standard)
    /// - Returns: A tuple of (color, opacity) for badge styling
    static func cefrBadgeStyle(for level: String, style: BadgeStyle = .standard) -> (color: Color, opacity: Double) {
        let color = self.cefrColor(for: level)
        let opacity: Double = switch style {
        case .compact:
            self.cefrBadgeOpacity(for: level) * 0.8 // Slightly lighter for compact
        case .standard:
            self.cefrBadgeOpacity(for: level)
        }

        return (color, opacity)
    }

    /// Badge style variants
    enum BadgeStyle {
        case standard // Full-size badges (e.g., on cards)
        case compact // Smaller badges (e.g., in lists)
    }

    // MARK: - Animation Constants

    /// Standard animation duration for UI transitions
    static let animationDuration: TimeInterval = 0.3

    /// Quick animation duration for micro-interactions
    static let quickAnimationDuration: TimeInterval = 0.15

    /// Spring animation for "Liquid Glass" feel
    static var springAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
    }

    // MARK: - Spacing Constants

    /// Standard spacing unit
    static let spacingUnit: CGFloat = 8

    /// Small spacing
    static let spacingSmall: CGFloat = 4

    /// Medium spacing
    static let spacingMedium: CGFloat = 12

    /// Large spacing
    static let spacingLarge: CGFloat = 16

    /// Extra large spacing
    static let spacingXLarge: CGFloat = 24

    // MARK: - Corner Radius

    /// Small corner radius for compact elements
    static let cornerRadiusSmall: CGFloat = 6

    /// Standard corner radius for cards and buttons
    static let cornerRadiusMedium: CGFloat = 12

    /// Large corner radius for prominent containers
    static let cornerRadiusLarge: CGFloat = 16

    // MARK: - Helper Methods

    /// Returns styled HStack for CEFR badge display
    /// - Parameters:
    ///   - level: The CEFR level string
    ///   - compact: Whether to use compact styling
    /// - Returns: A view builder function that creates the badge
    @ViewBuilder
    static func cefrBadge(level: String, compact: Bool = false) -> some View {
        let style = self.cefrBadgeStyle(for: level, style: compact ? .compact : .standard)

        HStack(spacing: compact ? 4 : 6) {
            if !compact {
                Text("CEFR")
                    .font(.caption2)
            }
            Text(level.uppercased())
                .font(compact ? .caption2 : .caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 2 : 4)
        .background(style.color.opacity(style.opacity))
        .foregroundStyle(style.color)
        .cornerRadius(compact ? self.cornerRadiusSmall : self.cornerRadiusMedium)
    }
}

// MARK: - View Extensions for Convenience

extension View {
    /// Applies CEFR badge color styling
    /// - Parameter level: The CEFR level string
    /// - Returns: The view with CEFR color applied
    func cefrStyled(for level: String) -> some View {
        foregroundStyle(Theme.cefrColor(for: level))
    }

    /// Applies CEFR background styling
    /// - Parameters:
    ///   - level: The CEFR level string
    ///   - style: The badge style
    /// - Returns: The view with CEFR background applied
    func cefrBackground(for level: String, style: Theme.BadgeStyle = .standard) -> some View {
        let style = Theme.cefrBadgeStyle(for: level, style: style)
        return background(style.color.opacity(style.opacity))
    }
}
