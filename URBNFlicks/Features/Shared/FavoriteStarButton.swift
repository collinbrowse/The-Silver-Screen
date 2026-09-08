//
//  FavoriteStarButton.swift
//  URBNFlicks
//

import SwiftUI

/// Circular star control for navigation bars (movie detail).
struct FavoriteStarButton: View {
    let isFavorite: Bool
    let action: () -> Void

    private let size: CGFloat = 32

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.green : Color.primary)
                .frame(width: size, height: size)
                .background(Color.clear)
                .overlay(
                    Circle()
                        .stroke(
                            isFavorite ? Color.green : Color.primary,
                            lineWidth: 1
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityValue(isFavorite ? "Favorited" : "Not favorited")
        .accessibilityAddTraits(.isButton)
    }
}
