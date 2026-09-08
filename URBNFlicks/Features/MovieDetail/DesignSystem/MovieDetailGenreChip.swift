//
//  MovieDetailGenreChip.swift
//  URBNFlicks
//

import SwiftUI

struct MovieDetailGenreChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MovieDetailTypography.chip)
            .foregroundStyle(MovieDetailTheme.textPrimary)
            .padding(.horizontal, MovieDetailSpacing.md)
            .padding(.vertical, MovieDetailSpacing.xs + 2)
            .background(MovieDetailTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(MovieDetailTheme.separator.opacity(0.35), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }
}
