//
//  MediaMetadataPills.swift
//  TheSilverScreen
//
//  Genre pills shared by every title that shows genres, plus trailer play pills.
//

import SwiftUI

/// Wrapping genre pills, matching movie detail.
struct GenreChipRow: View {
    let names: [String]
    /// Speaks the genre list. Rows that already include genres in their label turn this off.
    var announces: Bool = true

    var body: some View {
        FlowLayout(spacing: DesignSpacing.sm) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                TagChip(title: name)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(announces ? "Genres: \(names.joined(separator: ", "))" : "")
        .accessibilityHidden(!announces)
    }
}

/// Play control in the genre-pill shape. The triangle is the play icon.
struct TrailerChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.xs) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(DesignTypography.chip)
            .foregroundStyle(DesignTheme.textPrimary)
            .padding(.horizontal, DesignSpacing.md)
            .padding(.vertical, DesignSpacing.xs + 2)
            .frame(minHeight: 44, alignment: .leading)
            .background(DesignTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(DesignTheme.separator.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(title)")
    }
}

/// Genre pills, then one play pill for each official trailer.
struct MediaMetadataPills: View {
    var genres: [MovieGenre] = []
    var trailers: [MediaTrailer] = []
    var playTrailer: (MediaTrailer) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            if !genres.isEmpty {
                GenreChipRow(names: genres.map(\.name))
            }
            if !trailers.isEmpty {
                FlowLayout(spacing: DesignSpacing.sm) {
                    ForEach(trailers) { trailer in
                        TrailerChip(title: trailer.title) {
                            playTrailer(trailer)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
