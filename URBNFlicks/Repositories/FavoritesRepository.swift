//
//  FavoritesRepository.swift
//  URBNFlicks
//

import Foundation

/// Snapshot of a person captured from a credits cell at favorite time.
struct FavoritePerson: Sendable, Equatable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?
}

/// Snapshot of a TV series captured from an Acting/Crew credits cell at favorite time.
/// `releaseDate` holds the series' first air date.
struct FavoriteTVSeries: Sendable, Equatable {
    let id: Int
    let name: String
    let posterPath: String?
    let releaseDate: Date?
    let genreIDs: [Int]
}

actor FavoritesRepository {
    private let store: any FavoritesStore
    private let logger: any AppLogging
    private let index: FavoritesIndex
    private var cached: [FavoriteRecord]?

    @MainActor
    init(
        store: any FavoritesStore,
        logger: any AppLogging,
        index: FavoritesIndex = FavoritesIndex()
    ) {
        self.store = store
        self.logger = logger
        self.index = index
    }

    func favorites() async throws -> [FavoriteRecord] {
        let records = try await loadCache()
        return Self.sorted(records)
    }

    /// Reads persistence into the shared index. Call once at launch; later calls hit the cache.
    func loadIndex() async throws {
        try await loadCache()
    }

    func isFavorite(id: Int, kind: FavoriteKind) async throws -> Bool {
        let records = try await loadCache()
        return records.contains { $0.id == id && $0.kind == kind }
    }

    /// Person ids currently saved as favorites; used to paint cast/crew stars.
    func favoritePersonIDs() async throws -> Set<Int> {
        let records = try await loadCache()
        return Set(records.filter { $0.kind == .person }.map(\.id))
    }

    /// Movie ids currently saved as favorites; used to paint similar/collection stars.
    func favoriteMovieIDs() async throws -> Set<Int> {
        let records = try await loadCache()
        return Set(records.filter { $0.kind == .movie }.map(\.id))
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

    /// Returns whether the TV series is favorited after the toggle.
    @discardableResult
    func toggle(tv: FavoriteTVSeries, favoritedAt: Date = Date()) async throws -> Bool {
        var records = try await loadCache()
        if let index = records.firstIndex(where: { $0.id == tv.id && $0.kind == .tv }) {
            records.remove(at: index)
            try await persist(records)
            return false
        }

        let record = FavoriteRecord(
            id: tv.id,
            kind: .tv,
            favoritedAt: favoritedAt,
            title: tv.name,
            posterPath: tv.posterPath,
            releaseDate: tv.releaseDate,
            genreNames: TVGenreCatalog.names(for: tv.genreIDs)
        )
        records.append(record)
        try await persist(records)
        return true
    }

    /// Returns whether the person is favorited after the toggle.
    @discardableResult
    func toggle(person: FavoritePerson, favoritedAt: Date = Date()) async throws -> Bool {
        var records = try await loadCache()
        if let index = records.firstIndex(where: { $0.id == person.id && $0.kind == .person }) {
            records.remove(at: index)
            try await persist(records)
            return false
        }

        let genreNames: [String]
        if let department = person.knownForDepartment?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !department.isEmpty {
            genreNames = [department]
        } else {
            genreNames = []
        }

        let record = FavoriteRecord(
            id: person.id,
            kind: .person,
            favoritedAt: favoritedAt,
            title: person.name,
            posterPath: person.profilePath,
            releaseDate: nil,
            genreNames: genreNames
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

    /// Loads from disk once, then serves memory. Publishes ids into `FavoritesIndex`.
    @discardableResult
    private func loadCache() async throws -> [FavoriteRecord] {
        if let cached {
            return cached
        }
        do {
            let records = try await store.load()
            cached = records
            await index.replace(with: records)
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
            await index.replace(with: records)
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
