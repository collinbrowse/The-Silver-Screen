//
//  FavoritesRepositoryTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class FavoritesRepositoryTests: XCTestCase {

    func test_toggle_addsFavoriteWithGenreNamesSnapshot() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let movie = TestMovies.make(
            id: 278,
            title: "The Shawshank Redemption",
            posterPath: "/poster.jpg",
            releaseDate: TestMovies.date("1994-09-23"),
            genreIDs: [18, 80]
        )
        let favoritedAt = TestMovies.date("2024-06-01")

        let isFavorite = try await repository.toggle(movie: movie, favoritedAt: favoritedAt)

        XCTAssertTrue(isFavorite)
        let favorited = try await repository.isFavorite(id: 278, kind: .movie)
        XCTAssertTrue(favorited)
        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites[0].id, 278)
        XCTAssertEqual(favorites[0].kind, .movie)
        XCTAssertEqual(favorites[0].title, "The Shawshank Redemption")
        XCTAssertEqual(favorites[0].posterPath, "/poster.jpg")
        XCTAssertEqual(favorites[0].releaseDate, TestMovies.date("1994-09-23"))
        XCTAssertEqual(favorites[0].genreNames, ["Drama", "Crime"])
        XCTAssertEqual(favorites[0].favoritedAt, favoritedAt)
    }

    func test_toggle_removesExistingFavorite() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let movie = TestMovies.make(id: 1, title: "One", genreIDs: [28])

        _ = try await repository.toggle(movie: movie, favoritedAt: TestMovies.date("2024-01-01"))
        let isFavorite = try await repository.toggle(movie: movie, favoritedAt: TestMovies.date("2024-01-02"))

        XCTAssertFalse(isFavorite)
        let favorited = try await repository.isFavorite(id: 1, kind: .movie)
        XCTAssertFalse(favorited)
        let favorites = try await repository.favorites()
        XCTAssertTrue(favorites.isEmpty)
    }

    func test_favorites_sortsNewestFavoritedFirst() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let older = TestMovies.make(id: 1, title: "Older", genreIDs: [18])
        let newer = TestMovies.make(id: 2, title: "Newer", genreIDs: [28])

        _ = try await repository.toggle(movie: older, favoritedAt: TestMovies.date("2024-01-01"))
        _ = try await repository.toggle(movie: newer, favoritedAt: TestMovies.date("2024-06-15"))

        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.map(\.id), [2, 1])
    }

    func test_toggle_whenSaveFails_throwsPersistence() async {
        let store = InMemoryFavoritesStore()
        await store.setSaveError(CocoaError(.fileWriteUnknown))
        let repository = FavoritesRepository(store: store, logger: SilentLogger())

        do {
            _ = try await repository.toggle(movie: TestMovies.make(), favoritedAt: Date())
            XCTFail("Expected persistence error")
        } catch let error as AppError {
            XCTAssertEqual(error, .persistence)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_favorites_whenLoadFails_throwsPersistence() async {
        let store = InMemoryFavoritesStore()
        await store.setLoadError(CocoaError(.fileReadUnknown))
        let repository = FavoritesRepository(store: store, logger: SilentLogger())

        do {
            _ = try await repository.favorites()
            XCTFail("Expected persistence error")
        } catch let error as AppError {
            XCTAssertEqual(error, .persistence)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_genreCatalog_mapsKnownIds() {
        XCTAssertEqual(MovieGenreCatalog.names(for: [18, 80]), ["Drama", "Crime"])
        XCTAssertEqual(MovieGenreCatalog.names(for: [99999]), [])
    }

    func test_favoriteRecord_asMovie_preservesIdentityAndGenres() {
        let record = FavoriteRecord(
            id: 278,
            kind: .movie,
            favoritedAt: TestMovies.date("2024-06-01"),
            title: "The Shawshank Redemption",
            posterPath: "/poster.jpg",
            releaseDate: TestMovies.date("1994-09-23"),
            genreNames: ["Drama", "Crime"]
        )

        let movie = record.asMovie()

        XCTAssertEqual(movie.id, 278)
        XCTAssertEqual(movie.title, "The Shawshank Redemption")
        XCTAssertEqual(movie.posterPath, "/poster.jpg")
        XCTAssertEqual(movie.releaseDate, TestMovies.date("1994-09-23"))
        XCTAssertEqual(movie.genreIDs, [18, 80])
    }

    func test_togglePerson_addsFavoriteWithKnownForDepartment() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let person = FavoritePerson(
            id: 504,
            name: "Tim Robbins",
            profilePath: "/tim.jpg",
            knownForDepartment: "Acting"
        )
        let favoritedAt = TestMovies.date("2024-07-01")

        let isFavorite = try await repository.toggle(person: person, favoritedAt: favoritedAt)

        XCTAssertTrue(isFavorite)
        let isPersonFavorite = try await repository.isFavorite(id: 504, kind: .person)
        let isMovieFavorite = try await repository.isFavorite(id: 504, kind: .movie)
        XCTAssertTrue(isPersonFavorite)
        XCTAssertFalse(isMovieFavorite)
        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites[0].kind, .person)
        XCTAssertEqual(favorites[0].title, "Tim Robbins")
        XCTAssertEqual(favorites[0].posterPath, "/tim.jpg")
        XCTAssertNil(favorites[0].releaseDate)
        XCTAssertEqual(favorites[0].genreNames, ["Acting"])
        XCTAssertEqual(favorites[0].listID, "person-504")
    }

    func test_togglePerson_removesExistingFavorite() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let person = FavoritePerson(id: 1, name: "One", profilePath: nil, knownForDepartment: nil)

        _ = try await repository.toggle(person: person, favoritedAt: TestMovies.date("2024-01-01"))
        let isFavorite = try await repository.toggle(person: person, favoritedAt: TestMovies.date("2024-01-02"))

        XCTAssertFalse(isFavorite)
        let stillFavorited = try await repository.isFavorite(id: 1, kind: .person)
        XCTAssertFalse(stillFavorited)
        let favorites = try await repository.favorites()
        XCTAssertTrue(favorites.isEmpty)
    }

    func test_movieAndPerson_sameID_coexistAsSeparateRecords() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let movie = TestMovies.make(id: 500, title: "Reservoir Dogs", genreIDs: [80])
        let person = FavoritePerson(
            id: 500,
            name: "Tom Cruise",
            profilePath: "/cruise.jpg",
            knownForDepartment: "Acting"
        )

        _ = try await repository.toggle(movie: movie, favoritedAt: TestMovies.date("2024-01-01"))
        _ = try await repository.toggle(person: person, favoritedAt: TestMovies.date("2024-02-01"))

        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, 2)
        XCTAssertEqual(Set(favorites.map(\.listID)), Set(["movie-500", "person-500"]))
        let isMovieFavorite = try await repository.isFavorite(id: 500, kind: .movie)
        let isPersonFavorite = try await repository.isFavorite(id: 500, kind: .person)
        XCTAssertTrue(isMovieFavorite)
        XCTAssertTrue(isPersonFavorite)
        let personIDs = try await repository.favoritePersonIDs()
        XCTAssertEqual(personIDs, [500])
    }

    func test_toggleTV_addsFavoriteWithTVGenreNames() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let tv = FavoriteTVSeries(
            id: 1396,
            name: "Breaking Bad",
            posterPath: "/bb.jpg",
            releaseDate: TestMovies.date("2008-01-20"),
            genreIDs: [18, 10765]
        )
        let favoritedAt = TestMovies.date("2024-07-01")

        let isFavorite = try await repository.toggle(tv: tv, favoritedAt: favoritedAt)

        XCTAssertTrue(isFavorite)
        let isTVFavorite = try await repository.isFavorite(id: 1396, kind: .tv)
        XCTAssertTrue(isTVFavorite)
        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites[0].kind, .tv)
        XCTAssertEqual(favorites[0].title, "Breaking Bad")
        XCTAssertEqual(favorites[0].posterPath, "/bb.jpg")
        XCTAssertEqual(favorites[0].releaseDate, TestMovies.date("2008-01-20"))
        XCTAssertEqual(favorites[0].genreNames, ["Drama", "Sci-Fi & Fantasy"])
        XCTAssertEqual(favorites[0].listID, "tv-1396")
    }

    func test_toggleTV_removesExistingFavorite() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let tv = FavoriteTVSeries(id: 1, name: "One", posterPath: nil, releaseDate: nil, genreIDs: [])

        _ = try await repository.toggle(tv: tv, favoritedAt: TestMovies.date("2024-01-01"))
        let isFavorite = try await repository.toggle(tv: tv, favoritedAt: TestMovies.date("2024-01-02"))

        XCTAssertFalse(isFavorite)
        let stillFavorited = try await repository.isFavorite(id: 1, kind: .tv)
        XCTAssertFalse(stillFavorited)
        let favorites = try await repository.favorites()
        XCTAssertTrue(favorites.isEmpty)
    }

    func test_movieAndTV_sameID_coexistIndependentlyInStoreAndIndex() async throws {
        let index = FavoritesIndex()
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger(), index: index)
        let movie = TestMovies.make(id: 1396, title: "Movie 1396", genreIDs: [80])
        let tv = FavoriteTVSeries(
            id: 1396,
            name: "Breaking Bad",
            posterPath: nil,
            releaseDate: nil,
            genreIDs: [18]
        )

        _ = try await repository.toggle(movie: movie, favoritedAt: TestMovies.date("2024-01-01"))
        _ = try await repository.toggle(tv: tv, favoritedAt: TestMovies.date("2024-02-01"))

        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, 2)
        XCTAssertEqual(Set(favorites.map(\.listID)), Set(["movie-1396", "tv-1396"]))
        XCTAssertEqual(index.movieIDs, [1396])
        XCTAssertEqual(index.tvIDs, [1396])

        // Removing the TV favorite must leave the movie favorite intact.
        _ = try await repository.toggle(tv: tv, favoritedAt: TestMovies.date("2024-03-01"))
        XCTAssertEqual(index.movieIDs, [1396])
        XCTAssertTrue(index.tvIDs.isEmpty)
    }

    func test_favoritePersonIDs_returnsOnlyPersonRecords() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 10, name: "A", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-01-02")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 20, name: "B", profilePath: nil, knownForDepartment: nil),
            favoritedAt: TestMovies.date("2024-01-03")
        )

        let personIDs = try await repository.favoritePersonIDs()
        XCTAssertEqual(personIDs, [10, 20])
    }

    func test_favoriteMovieIDs_returnsOnlyMovieRecords() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 10, name: "A", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-01-02")
        )

        let movieIDs = try await repository.favoriteMovieIDs()
        XCTAssertEqual(movieIDs, [1])
    }

    func test_toggle_publishesIdsToSharedIndex() async throws {
        let index = FavoritesIndex()
        let repository = FavoritesRepository(
            store: InMemoryFavoritesStore(),
            logger: SilentLogger(),
            index: index
        )
        let movie = TestMovies.make(id: 278, title: "Shawshank", genreIDs: [18])
        let person = FavoritePerson(
            id: 504,
            name: "Tim Robbins",
            profilePath: nil,
            knownForDepartment: "Acting"
        )

        _ = try await repository.toggle(movie: movie, favoritedAt: TestMovies.date("2024-01-01"))
        _ = try await repository.toggle(person: person, favoritedAt: TestMovies.date("2024-01-02"))

        XCTAssertEqual(index.movieIDs, [278])
        XCTAssertEqual(index.personIDs, [504])

        _ = try await repository.toggle(person: person, favoritedAt: TestMovies.date("2024-01-03"))
        XCTAssertTrue(index.personIDs.isEmpty)
        XCTAssertEqual(index.movieIDs, [278])
    }

    func test_refresh_updatesSnapshotOfFavoritedMovie_preservingFavoritedAt() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let favoritedAt = TestMovies.date("2024-06-01")
        _ = try await repository.toggle(
            movie: TestMovies.make(
                id: 278,
                title: "Old Title",
                posterPath: "/old.jpg",
                releaseDate: TestMovies.date("1994-01-01"),
                genreIDs: [18]
            ),
            favoritedAt: favoritedAt
        )

        let changed = try await repository.refresh(
            movie: TestMovies.make(
                id: 278,
                title: "The Shawshank Redemption",
                posterPath: "/new.jpg",
                releaseDate: TestMovies.date("1994-09-23"),
                genreIDs: [18, 80]
            )
        )

        XCTAssertTrue(changed)
        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites[0].title, "The Shawshank Redemption")
        XCTAssertEqual(favorites[0].posterPath, "/new.jpg")
        XCTAssertEqual(favorites[0].releaseDate, TestMovies.date("1994-09-23"))
        XCTAssertEqual(favorites[0].genreNames, ["Drama", "Crime"])
        XCTAssertEqual(favorites[0].favoritedAt, favoritedAt)
    }

    func test_refresh_whenMovieNotFavorited_isNoOp() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())

        let changed = try await repository.refresh(
            movie: TestMovies.make(id: 999, title: "Ghost", genreIDs: [18])
        )

        XCTAssertFalse(changed)
        let favorites = try await repository.favorites()
        XCTAssertTrue(favorites.isEmpty)
    }

    func test_refresh_whenSnapshotUnchanged_isNoOp() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let movie = TestMovies.make(
            id: 1,
            title: "Same",
            posterPath: "/same.jpg",
            releaseDate: TestMovies.date("2020-01-01"),
            genreIDs: [18]
        )
        _ = try await repository.toggle(movie: movie, favoritedAt: TestMovies.date("2024-01-01"))

        let changed = try await repository.refresh(movie: movie)

        XCTAssertFalse(changed)
    }

    func test_toggle_concurrentTogglesOfDistinctMovies_allPersist() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        let count = 50

        // Fire all toggles at once. Without write serialization, actor reentrancy at
        // `store.save` lets these interleave and clobber one another (a lost update).
        await withTaskGroup(of: Void.self) { group in
            for id in 0..<count {
                group.addTask {
                    _ = try? await repository.toggle(
                        movie: TestMovies.make(id: id, title: "Movie \(id)", genreIDs: [18]),
                        favoritedAt: TestMovies.date("2024-01-01")
                    )
                }
            }
        }

        let favorites = try await repository.favorites()
        XCTAssertEqual(favorites.count, count)
        XCTAssertEqual(Set(favorites.map(\.id)), Set(0..<count))
    }

    func test_loadIndex_publishesPersistedRecords() async throws {
        let index = FavoritesIndex()
        let store = InMemoryFavoritesStore(records: [
            FavoriteRecord(
                id: 278,
                kind: .movie,
                favoritedAt: TestMovies.date("2024-01-01"),
                title: "Shawshank",
                posterPath: nil,
                releaseDate: nil,
                genreNames: ["Drama"]
            ),
            FavoriteRecord(
                id: 504,
                kind: .person,
                favoritedAt: TestMovies.date("2024-01-02"),
                title: "Tim Robbins",
                posterPath: nil,
                releaseDate: nil,
                genreNames: ["Acting"]
            ),
        ])
        let repository = FavoritesRepository(store: store, logger: SilentLogger(), index: index)

        try await repository.loadIndex()

        XCTAssertEqual(index.movieIDs, [278])
        XCTAssertEqual(index.personIDs, [504])
    }
}
