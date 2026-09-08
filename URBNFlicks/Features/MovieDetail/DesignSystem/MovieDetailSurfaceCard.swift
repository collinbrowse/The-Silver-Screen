//
//  MovieDetailSurfaceCard.swift
//  URBNFlicks
//

import SwiftUI

struct MovieDetailSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(MovieDetailSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MovieDetailTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: MovieDetailRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MovieDetailRadius.card, style: .continuous)
                    .strokeBorder(MovieDetailTheme.separator.opacity(0.35), lineWidth: 0.5)
            )
    }
}
