//
//  PersonFavoriteStar.swift
//  URBNFlicks
//

import SwiftUI

/// Star overlaid on the top-trailing corner of a carousel poster or profile card.
struct CellFavoriteStar: View {
    let name: String
    let isFavorite: Bool
    let action: () -> Void

    private let glyphSize: CGFloat = 22
    private let hitSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: glyphSize + 10, height: glyphSize + 10)
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
