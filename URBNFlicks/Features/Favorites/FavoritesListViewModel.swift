//
//  FavoritesListViewModel.swift
//  URBNFlicks
//

import Foundation

/// Which favorite kinds the list shows.
enum FavoritesFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case movies
    case tvSeries
    case people

    var title: String {
        switch self {
        case .all: return "All"
        case .movies: return "Movies"
        case .tvSeries: return "TV"
        case .people: return "People"
        }
    }
}

@Observable
@MainActor
final class FavoritesListViewModel {
    private(set) var state: LoadState<[FavoriteRecord]> = .idle
    private(set) var toggleError: AppError?

    /// Active kind filter; preserved across reloads because this VM is long-lived.
    var filter: FavoritesFilter = .all
    /// In-memory title/name query; applied after `filter`.
    var searchText: String = ""

    private let favorites: FavoritesRepository

    init(favorites: FavoritesRepository) {
        self.favorites = favorites
    }

    /// Records visible under the current filter and search. Derived from `state`.
    var displayedFavorites: [FavoriteRecord] {
        guard case .loaded(let records, _) = state else { return [] }
        let filtered: [FavoriteRecord]
        switch filter {
        case .all:
            filtered = records
        case .movies:
            filtered = records.filter { $0.kind == .movie }
        case .tvSeries:
            filtered = records.filter { $0.kind == .tv }
        case .people:
            filtered = records.filter { $0.kind == .person }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filtered }
        return filtered.filter { $0.title.localizedStandardContains(query) }
    }

    func load() async {
        // Only a cold load shows the full-screen spinner. Returning to the tab (`onAppear` fires
        // again) is a refresh that keeps the current list on screen instead of throwing it away
        // and flashing a spinner.
        if case .loaded(let current, _) = state {
            state = .loaded(current, activity: .refreshing)
        } else if case .empty = state {
            // Keep the empty state; re-fetch silently.
        } else {
            state = .loading
        }
        toggleError = nil
        do {
            let records = try await favorites.favorites()
            apply(records)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            failRefresh(with: error)
        } catch {
            failRefresh(with: .unknown)
        }
    }

    /// A refresh failure keeps any content already on screen; only a cold failure is full-screen.
    private func failRefresh(with error: AppError) {
        if case .loaded(let current, _) = state {
            state = .loaded(current, activity: .failed(error))
        } else {
            state = .failed(error)
        }
    }

    func retry() async {
        await load()
    }

    /// Removes a favorite from the list (swipe-to-delete / unfavorite).
    func toggleFavorite(_ record: FavoriteRecord) async {
        guard case .loaded(let current, _) = state else { return }
        toggleError = nil

        do {
            try await favorites.remove(id: record.id, kind: record.kind)
            let records = try await favorites.favorites()
            apply(records)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            toggleError = error
            state = .loaded(current, activity: .failed(error))
        } catch {
            toggleError = .unknown
            state = .loaded(current, activity: .failed(.unknown))
        }
    }

    /// Deletes rows by index into `displayedFavorites` (not the unfiltered `state` array).
    func removeFavorites(at offsets: IndexSet) async {
        let displayed = displayedFavorites
        let toRemove = offsets.compactMap { index -> FavoriteRecord? in
            guard displayed.indices.contains(index) else { return nil }
            return displayed[index]
        }
        for record in toRemove {
            await toggleFavorite(record)
            if toggleError != nil { return }
        }
    }

    private func apply(_ records: [FavoriteRecord]) {
        if records.isEmpty {
            state = .empty
        } else {
            state = .loaded(records)
        }
    }
}
