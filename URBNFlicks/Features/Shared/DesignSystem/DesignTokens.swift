//
//  DesignTokens.swift
//  URBNFlicks
//
//  Shared visual language for new SwiftUI screens. The legacy Top Movies UIKit
//  list stays on Comps/redline.png and should not adopt these tokens.
//

import SwiftUI

enum DesignSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum DesignRadius {
    static let poster: CGFloat = 10
    static let card: CGFloat = 14
    /// Apple TV–style carousel cards (continuous rounded rect).
    static let carousel: CGFloat = 22
    static let chip: CGFloat = 100
}

enum DesignTheme {
    /// Near-black in dark mode; system background in light.
    static var canvas: Color { Color(.systemBackground) }

    /// Card / chip surfaces.
    static var surface: Color { Color(.secondarySystemBackground) }

    static var textPrimary: Color { Color(.label) }
    static var textSecondary: Color { Color(.secondaryLabel) }
    static var textMuted: Color { Color(.tertiaryLabel) }
    static var separator: Color { Color(.separator) }

    /// Brand amber/orange for new screens — does not overwrite app AccentColor
    /// (Top Movies keeps system blue).
    static var accent: Color { Color("DesignAccent") }

    static var accentOnFill: Color { Color.black }
}

enum DesignTypography {
    static var title: Font { .title2.bold() }
    static var section: Font { .headline }
    static var body: Font { .body }
    static var metadata: Font { .subheadline }
    static var factLabel: Font { .caption2.weight(.semibold) }
    static var factValue: Font { .title3.weight(.semibold) }
    static var chip: Font { .caption.weight(.medium) }
    static var ratingValue: Font { .title2.bold() }
}
