//
//  FavoritePillButton.swift
//  URBNFlicks
//

import SwiftUI

struct FavoritePillButton: View {
    let isFavorite: Bool
    let action: () -> Void

    @State private var iconRotation: Double = 0
    @State private var pillScale: CGFloat = 1
    @State private var displayedFavorite: Bool
    @State private var animationTask: Task<Void, Never>?

    init(isFavorite: Bool, action: @escaping () -> Void) {
        self.isFavorite = isFavorite
        self.action = action
        _displayedFavorite = State(initialValue: isFavorite)
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 4) {
                Image(systemName: displayedFavorite ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(iconRotation))
                Text("Favorite")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .foregroundStyle(displayedFavorite ? Color.green : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.clear)
            .overlay(
                Capsule()
                    .stroke(
                        displayedFavorite ? Color.green.opacity(0.85) : Color.primary.opacity(0.45),
                        lineWidth: 1
                    )
            )
            .scaleEffect(pillScale)
            // Keep layout bounds large enough for the reward pulse so UIKit hosts don't clip.
            .padding(4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(displayedFavorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityValue(displayedFavorite ? "Favorited" : "Not favorited")
        .accessibilityAddTraits(.isButton)
        .onChange(of: isFavorite) { _, newValue in
            animationTask?.cancel()
            displayedFavorite = newValue
            iconRotation = 0
            pillScale = 1
        }
    }

    private func handleTap() {
        let willFavorite = !displayedFavorite
        action()
        animationTask?.cancel()

        if willFavorite {
            animationTask = Task { @MainActor in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    pillScale = 1.14
                }
                withAnimation(.easeInOut(duration: 0.45)) {
                    iconRotation = 360
                }
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                displayedFavorite = true
                try? await Task.sleep(for: .milliseconds(230))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    pillScale = 1
                    iconRotation = 0
                }
            }
        } else {
            animationTask = Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedFavorite = false
                    iconRotation = 0
                    pillScale = 0.96
                }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    pillScale = 1
                }
            }
        }
    }
}
