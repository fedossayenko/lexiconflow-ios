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
    // MARK: - Semantic Colors

    /// Card background color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate background color
    static func cardBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : .white
    }

    /// Primary text color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate text color
    static func primaryText(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .primary
    }

    /// Secondary text color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate secondary text color
    static func secondaryText(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.7) : .secondary
    }

    /// Tertiary text color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate tertiary text color
    static func tertiaryText(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.5) : Color(white: 0.6)
    }

    /// Glass material that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate material for glass effects
    static func glassMaterial(colorScheme: ColorScheme) -> Material {
        colorScheme == .dark ? .thinMaterial : .ultraThinMaterial
    }

    /// Separator/divider color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate separator color
    static func separator(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.9)
    }

    /// Background fill color for secondary containers
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate fill color
    static func secondaryFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95)
    }

    // MARK: - Status Colors (Adaptive)

    /// Success color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate success color
    static func success(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .green : .green
    }

    /// Warning color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate warning color
    static func warning(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .orange : .orange
    }

    /// Error color that adapts to color scheme
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: Appropriate error color
    static func error(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .red : .red
    }

    // MARK: - Semantic Color Constants

    /// Static color constants for consistent theming
    /// These colors do not adapt to color scheme - they are semantic labels
    /// for specific UI elements throughout the app
    enum Colors {
        // MARK: Status Colors

        /// Error/danger color
        static let error = Color.red

        /// Warning/caution color
        static let warning = Color.orange

        /// Success/completion color
        static let success = Color.green

        /// Primary accent color
        static let primary = Color.blue

        /// Destructive action color
        static let destructive = Color.red

        // MARK: FSRS State Colors

        /// New card state color
        static let stateNew = Color.purple

        /// Learning state color
        static let stateLearning = Color.blue

        /// Review state color
        static let stateReview = Color.green

        /// Relearning state color
        static let stateRelearning = Color.orange

        // MARK: Metric Colors

        /// Primary metric color (e.g., retention rate)
        static let metricPrimary = Color.blue

        /// Secondary metric color (e.g., study streak)
        static let metricSecondary = Color.orange

        /// Tertiary metric color (e.g., study time)
        static let metricTertiary = Color.green

        /// Quaternary metric color (e.g., cards reviewed)
        static let metricQuaternary = Color.purple

        // MARK: UI Element Colors

        /// CEFR badge color
        static let cefrBadge = Color.orange

        /// Favorite/star color
        static let favorite = Color.yellow

        /// Cached/offline indicator color
        static let cached = Color.green

        /// Fresh/new indicator color
        static let fresh = Color.blue
    }

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

    /// Applies themed card background
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: The view with card background applied
    func themedCardBackground(colorScheme: ColorScheme) -> some View {
        background(Theme.cardBackground(colorScheme: colorScheme))
    }

    /// Applies themed glass material
    /// - Parameter colorScheme: The current color scheme
    /// - Returns: The view with glass material applied
    func themedGlassMaterial(colorScheme: ColorScheme) -> some View {
        background(Theme.glassMaterial(colorScheme: colorScheme))
    }
}
