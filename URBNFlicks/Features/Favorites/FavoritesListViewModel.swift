//
//  FavoritesListViewModel.swift
//  URBNFlicks
//

import Foundation

@Observable
@MainActor
final class FavoritesListViewModel {
    private(set) var state: LoadState<[FavoriteRecord]> = .idle
    private(set) var toggleError: AppError?

    private let favorites: FavoritesRepository

    init(favorites: FavoritesRepository) {
        self.favorites = favorites
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

    func removeFavorites(at offsets: IndexSet) async {
        guard case .loaded(let current, _) = state else { return }
        let toRemove = offsets.compactMap { index -> FavoriteRecord? in
            guard current.indices.contains(index) else { return nil }
            return current[index]
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
