//
//  FavoritesRepositoryTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

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
        let favorited = try await repository.isFavorite(id: 278)
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
        let favorited = try await repository.isFavorite(id: 1)
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
}
