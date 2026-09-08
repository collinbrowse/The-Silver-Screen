//
//  FavoritesRepository.swift
//  URBNFlicks
//

import Foundation

actor FavoritesRepository {
    private let store: any FavoritesStore
    private let logger: any AppLogging
    private var cached: [FavoriteRecord]?

    init(store: any FavoritesStore, logger: any AppLogging) {
        self.store = store
        self.logger = logger
    }

    func favorites() async throws -> [FavoriteRecord] {
        let records = try await loadCache()
        return Self.sorted(records)
    }

    func isFavorite(id: Int) async throws -> Bool {
        let records = try await loadCache()
        return records.contains { $0.id == id && $0.kind == .movie }
    }

    /// Returns whether the movie is favorited after the toggle.
    @discardableResult
    func toggle(movie: Movie, favoritedAt: Date = Date()) async throws -> Bool {
        var records = try await loadCache()
        if let index = records.firstIndex(where: { $0.id == movie.id && $0.kind == .movie }) {
            records.remove(at: index)
            try await persist(records)
            return false
        }

        let record = FavoriteRecord(
            id: movie.id,
            kind: .movie,
            favoritedAt: favoritedAt,
            title: movie.title,
            posterPath: movie.posterPath,
            releaseDate: movie.releaseDate,
            genreNames: MovieGenreCatalog.names(for: movie.genreIDs)
        )
        records.append(record)
        try await persist(records)
        return true
    }

    func remove(id: Int, kind: FavoriteKind = .movie) async throws {
        var records = try await loadCache()
        let before = records.count
        records.removeAll { $0.id == id && $0.kind == kind }
        guard records.count != before else { return }
        try await persist(records)
    }

    // MARK: - Private

    private func loadCache() async throws -> [FavoriteRecord] {
        if let cached {
            return cached
        }
        do {
            let records = try await store.load()
            cached = records
            return records
        } catch {
            logger.error("Favorites load failed", category: .persistence)
            throw AppError.persistence
        }
    }

    private func persist(_ records: [FavoriteRecord]) async throws {
        do {
            try await store.save(records)
            cached = records
        } catch {
            logger.error("Favorites save failed", category: .persistence)
            throw AppError.persistence
        }
    }

    private static func sorted(_ records: [FavoriteRecord]) -> [FavoriteRecord] {
        records.sorted { lhs, rhs in
            if lhs.favoritedAt != rhs.favoritedAt {
                return lhs.favoritedAt > rhs.favoritedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
