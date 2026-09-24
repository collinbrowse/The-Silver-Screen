//
//  PersonFavoriteStar.swift
//  URBNFlicks
//

import SwiftUI

/// Star control for carousel overlays, list posters, and the movie-detail navigation bar.
struct CellFavoriteStar: View {
    let name: String
    let isFavorite: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let glyphSize: CGFloat = 22
    private let hitSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color(white: 0.24) : Color.black.opacity(0.45))
                    .frame(width: glyphSize + 14, height: glyphSize + 14)
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: glyphSize * 0.55, weight: .semibold))
                    .foregroundStyle(isFavorite ? Color.yellow : Color.white)
            }
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isFavorite
                ? "Remove \(name) from Favorites"
                : "Add \(name) to Favorites"
        )
        .accessibilityValue(isFavorite ? "Favorited" : "Not favorited")
        .accessibilityAddTraits(.isButton)
    }
}

/// Cast/crew alias for the shared carousel star overlay.
typealias PersonFavoriteStar = CellFavoriteStar
