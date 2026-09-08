//
//  FavoritesListView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

struct FavoritesListView: View {
    @State var viewModel: FavoritesListViewModel
    let imageLoader: ImageLoader

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                EmptyStateView(
                    title: "No Favorites Yet",
                    message: "Tap Favorite on a movie to save it here.",
                    systemImage: "heart"
                )
            case .loaded(let favoritesList, let activity):
                List {
                    ForEach(favoritesList) { favorite in
                        NavigationLink(value: Route.movieDetail(id: favorite.id)) {
                            FavoriteMovieRow(favorite: favorite, imageLoader: imageLoader)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.toggleFavorite(favorite) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .accessibilityLabel("Remove Favorite")
                        }
                    }
                    .onDelete { offsets in
                        Task { await viewModel.removeFavorites(at: offsets) }
                    }
                }
                .listStyle(.plain)
                .overlay(alignment: .top) {
                    if case .failed(let error) = activity {
                        Text("\(error.title): \(error.message)")
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .accessibilityLabel("\(error.title). \(error.message)")
                    }
                }
            case .failed(let error):
                ErrorStateView(error: error) {
                    await viewModel.retry()
                }
            }
        }
        .onAppear {
            Task { await viewModel.load() }
        }
    }
}

private struct FavoriteMovieRow: View {
    let favorite: FavoriteRecord
    let imageLoader: ImageLoader

    @State private var poster: UIImage?
    @Environment(\.displayScale) private var displayScale

    private let posterSize = CGSize(width: 70, height: 105)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            posterView
            VStack(alignment: .leading, spacing: 6) {
                Text(favorite.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !favorite.genreNames.isEmpty {
                    Text(favorite.genreNames.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(Self.releaseDateText(for: favorite.releaseDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .task(id: favorite.id) {
            await loadPoster()
        }
    }

    private var posterView: some View {
        Group {
            if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: posterSize.width, height: posterSize.height)
        .clipped()
        .accessibilityHidden(true)
    }

    private var accessibilitySummary: String {
        var parts = [favorite.title]
        if !favorite.genreNames.isEmpty {
            parts.append(favorite.genreNames.joined(separator: ", "))
        }
        parts.append(Self.releaseDateText(for: favorite.releaseDate))
        return parts.joined(separator: ", ")
    }

    private func loadPoster() async {
        poster = nil
        guard let path = favorite.posterPath,
              let url = ImageLoader.posterURL(
                path: path,
                targetWidthPoints: posterSize.width,
                scale: displayScale
              ) else {
            return
        }
        let expectedID = favorite.id
        let image = try? await imageLoader.image(
            for: url,
            targetSize: posterSize,
            scale: displayScale
        )
        guard expectedID == favorite.id else { return }
        poster = image
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func releaseDateText(for date: Date?) -> String {
        guard let date else { return "Release date unavailable" }
        return dateFormatter.string(from: date)
    }
}
