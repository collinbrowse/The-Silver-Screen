//
//  DetailCarousel.swift
//  URBNFlicks
//

import SwiftUI

/// Apple TV–style horizontal carousel: section title, peek of the next card, continuous corners.
struct DetailCarousel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text(title)
                .font(DesignTypography.section)
                .foregroundStyle(DesignTheme.textPrimary)
                .padding(.horizontal, DesignSpacing.lg)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DesignSpacing.md) {
                    content()
                }
                .scrollTargetLayout()
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.vertical, DesignSpacing.xs)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .scrollEdgeEffectHidden(true)
        }
    }
}

struct CarouselCardFrame: ViewModifier {
    let width: CGFloat
    let aspectRatio: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: width / aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.carousel, style: .continuous))
    }
}

extension View {
    func carouselCard(width: CGFloat, aspectRatio: CGFloat) -> some View {
        modifier(CarouselCardFrame(width: width, aspectRatio: aspectRatio))
    }
}
