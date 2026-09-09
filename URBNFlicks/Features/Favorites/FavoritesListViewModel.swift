//
//  FavoritesListViewModel.swift
//  URBNFlicks
//

import Foundation

/// Which favorite kinds the list shows. No TV case: TV favorites cannot be created (stories 4-5 are open).
enum FavoritesFilter: String, CaseIterable, Sendable, Equatable {
    case all
    case movies
    case people

    var title: String {
        switch self {
        case .all: return "All"
        case .movies: return "Movies"
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

    private let favorites: FavoritesRepository

    init(favorites: FavoritesRepository) {
        self.favorites = favorites
    }

    /// Records visible under the current filter (and later, search). Derived from `state`.
    var displayedFavorites: [FavoriteRecord] {
        guard case .loaded(let records, _) = state else { return [] }
        switch filter {
        case .all:
            return records
        case .movies:
            return records.filter { $0.kind == .movie }
        case .people:
            return records.filter { $0.kind == .person }
        }
    }

    func load() async {
        state = .loading
        toggleError = nil
        do {
            let records = try await favorites.favorites()
            apply(records)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
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
