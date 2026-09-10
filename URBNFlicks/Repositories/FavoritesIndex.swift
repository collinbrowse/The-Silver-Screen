//
//  FavoritesIndex.swift
//  URBNFlicks
//

import Foundation

/// Live favorite ids shared across screens so star controls stay in sync.
///
/// `FavoritesRepository` publishes here after every load/persist. Views read these
/// sets directly so Observation redraws stars without copying ids into each screen's `LoadState`.
@Observable
@MainActor
final class FavoritesIndex {
    private(set) var movieIDs: Set<Int> = []
    private(set) var personIDs: Set<Int> = []

    func contains(_ id: Int, kind: FavoriteKind) -> Bool {
        switch kind {
        case .movie: return movieIDs.contains(id)
        case .person: return personIDs.contains(id)
        }
    }

    func replace(with records: [FavoriteRecord]) {
        movieIDs = Set(records.filter { $0.kind == .movie }.map(\.id))
        personIDs = Set(records.filter { $0.kind == .person }.map(\.id))
    }
}
