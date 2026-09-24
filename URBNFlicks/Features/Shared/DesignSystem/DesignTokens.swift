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
    /// Continuous corner radius for posters, surface cards, and carousel media
    /// on new SwiftUI screens (iOS 26 / Apple TV–style squircle language).
    static let media: CGFloat = 22
    static let poster: CGFloat = media
    static let card: CGFloat = media
    static let carousel: CGFloat = media
    /// Fully rounded pills (genre chips).
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

/// Inline navigation title that stays out of the bar until the page scrolls, then comes back out at the top.
struct ScrollingInlineTitle: ViewModifier {
    let title: String
    @State private var showsTitle = false

    func body(content: Content) -> some View {
        content
            .navigationTitle(showsTitle && !title.isEmpty ? title : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 12
            } action: { _, shouldShow in
                guard shouldShow != showsTitle else { return }
                withAnimation(.smooth(duration: 0.25)) {
                    showsTitle = shouldShow
                }
            }
    }
}

extension View {
    func scrollingInlineTitle(_ title: String) -> some View {
        modifier(ScrollingInlineTitle(title: title))
    }
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
