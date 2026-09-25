//
//  TMDBRatingCard.swift
//  TheSilverScreen
//
//  Star card for a TMDB user score. Movies, series, seasons, and episodes share it.
//

import SwiftUI

struct TMDBRatingCard: View {
    let formattedRating: String
    let accessibilityLabel: String

    var body: some View {
        SurfaceCard {
            HStack(spacing: DesignSpacing.md) {
                Image(systemName: "star.fill")
                    .foregroundStyle(DesignTheme.accent)
                    .accessibilityHidden(true)
                    .accessibilityLabel("")
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(formattedRating)
                        .font(DesignTypography.ratingValue)
                        .foregroundStyle(DesignTheme.textPrimary)
                    Text("TMDB RATING")
                        .font(DesignTypography.factLabel)
                        .foregroundStyle(DesignTheme.textMuted)
                        .tracking(0.6)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}
