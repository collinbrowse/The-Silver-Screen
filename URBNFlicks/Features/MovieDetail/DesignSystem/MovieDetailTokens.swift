//
//  MovieDetailTokens.swift
//  URBNFlicks
//
//  Screen-scoped visual language for Movie Detail. Top Movies stays on redline.
//

import SwiftUI

enum MovieDetailSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum MovieDetailRadius {
    static let poster: CGFloat = 10
    static let card: CGFloat = 14
    static let chip: CGFloat = 100
}

enum MovieDetailTheme {
    /// Near-black in dark mode; system background in light.
    static var canvas: Color { Color(.systemBackground) }

    /// Card / chip surfaces.
    static var surface: Color { Color(.secondarySystemBackground) }

    static var textPrimary: Color { Color(.label) }
    static var textSecondary: Color { Color(.secondaryLabel) }
    static var textMuted: Color { Color(.tertiaryLabel) }
    static var separator: Color { Color(.separator) }

    /// Detail-local amber/orange — does not overwrite app AccentColor.
    static var accent: Color { Color("MovieDetailAccent") }

    static var accentOnFill: Color { Color.black }
}

enum MovieDetailTypography {
    static var title: Font { .title2.bold() }
    static var section: Font { .headline }
    static var body: Font { .body }
    static var metadata: Font { .subheadline }
    static var factLabel: Font { .caption2.weight(.semibold) }
    static var factValue: Font { .title3.weight(.semibold) }
    static var chip: Font { .caption.weight(.medium) }
    static var ratingValue: Font { .title2.bold() }
}
