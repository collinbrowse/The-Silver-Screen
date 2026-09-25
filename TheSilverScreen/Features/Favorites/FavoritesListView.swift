//
//  FavoritesListView.swift
//  TheSilverScreen
//

import SwiftUI

struct FavoritesListView: View {
    @Bindable var viewModel: FavoritesListViewModel
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
                    message: "Favorite a movie, TV series, or person to save it here.",
                    systemImage: "heart"
                )
            case .loaded(_, let activity):
                loadedBody(activity: activity)
            case .failed(let error):
                ErrorStateView(error: error) {
                    await viewModel.retry()
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if case .loaded = viewModel.state {
                filterPicker
                    .background(DesignTheme.canvas)
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search favorites"
        )
        .onAppear {
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func loadedBody(activity: LoadActivity) -> some View {
        let displayed = viewModel.displayedFavorites
        Group {
            if displayed.isEmpty {
                EmptyStateView(
                    title: noMatchesTitle,
                    message: noMatchesMessage,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(displayed, id: \.listID) { favorite in
                        favoriteRow(favorite)
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
            }
        }
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
    }

    private var filterPicker: some View {
        Picker("Filter favorites", selection: $viewModel.filter) {
            ForEach(FavoritesFilter.allCases, id: \.self) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityLabel("Filter favorites")
    }

    private var noMatchesTitle: String {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return "No Matches"
        }
        switch viewModel.filter {
        case .all: return "No Matches"
        case .movies: return "No Movie Favorites"
        case .tvSeries: return "No TV Favorites"
        case .people: return "No People Favorites"
        }
    }

    private var noMatchesMessage: String {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            switch viewModel.filter {
            case .all:
                return "Nothing matches \"\(query)\"."
            case .movies:
                return "No movies match \"\(query)\"."
            case .tvSeries:
                return "No TV series match \"\(query)\"."
            case .people:
                return "No people match \"\(query)\"."
            }
        }
        switch viewModel.filter {
        case .all: return "Nothing matches the current filter."
        case .movies: return "Favorite a movie to see it here."
        case .tvSeries: return "Favorite a TV series from a cast or crew card to see it here."
        case .people: return "Favorite a person from a cast or crew card to see them here."
        }
    }

    @ViewBuilder
    private func favoriteRow(_ favorite: FavoriteRecord) -> some View {
        switch favorite.kind {
        case .movie:
            NavigationLink(value: Route.movieDetail(id: favorite.id)) {
                FavoriteTitleRow(
                    favorite: favorite,
                    userScore: viewModel.userScores[favorite.listID]?.formatted,
                    imageLoader: imageLoader
                )
            }
        case .tv:
            NavigationLink(value: Route.tvSeries(id: favorite.id)) {
                FavoriteTitleRow(
                    favorite: favorite,
                    userScore: viewModel.userScores[favorite.listID]?.formatted,
                    imageLoader: imageLoader
                )
            }
        case .person:
            NavigationLink(value: Route.person(id: favorite.id)) {
                FavoritePersonRow(favorite: favorite, imageLoader: imageLoader)
            }
        }
    }
}

/// Favorites row for a bookmarked movie or TV series: poster, title, genres, and date.
private struct FavoriteTitleRow: View {
    let favorite: FavoriteRecord
    /// Personal score under the date. Not a control.
    var userScore: String? = nil
    let imageLoader: ImageLoader

    private let posterWidth: CGFloat = 120

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImageView(
                path: favorite.posterPath,
                kind: .poster,
                width: posterWidth,
                aspectRatio: 2 / 3,
                imageLoader: imageLoader,
                placeholderSystemImage: favorite.kind == .tv ? "tv" : "film"
            )
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
                if let userScore {
                    Text(userScore)
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.accent)
                        .accessibilityLabel("Your rating, \(userScore)")
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [favorite.title]
        if !favorite.genreNames.isEmpty {
            parts.append(favorite.genreNames.joined(separator: ", "))
        }
        parts.append(Self.releaseDateText(for: favorite.releaseDate))
        if let userScore {
            parts.append(userScore)
        }
        return parts.joined(separator: ", ")
    }

    static func releaseDateText(for date: Date?) -> String {
        DisplayDate.day(date)
    }
}

/// Favorites row for a bookmarked person.
private struct FavoritePersonRow: View {
    let favorite: FavoriteRecord
    let imageLoader: ImageLoader

    private let profileWidth: CGFloat = 120
    private let profileAspect: CGFloat = 2 / 3

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImageView(
                path: favorite.posterPath,
                kind: .profile,
                width: profileWidth,
                aspectRatio: profileAspect,
                imageLoader: imageLoader,
                placeholderSystemImage: "person.fill"
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.poster, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(favorite.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !favorite.genreNames.isEmpty {
                    Text(favorite.genreNames.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Person")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [favorite.title]
        if !favorite.genreNames.isEmpty {
            parts.append(favorite.genreNames.joined(separator: ", "))
        }
        parts.append("Person")
        return parts.joined(separator: ", ")
    }
}
