//
//  FavoritesListViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class FavoritesListViewModelTests: XCTestCase {

    func test_load_whenEmpty_setsEmptyState() async {
        let store = InMemoryFavoritesStore()
        let viewModel = FavoritesListViewModel(
            favorites: FavoritesRepository(store: store, logger: SilentLogger())
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .empty)
    }

    func test_load_whenFavoritesExist_setsLoadedNewestFirst() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Older", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 2, title: "Newer", genreIDs: [28]),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)

        await viewModel.load()

        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.id), [2, 1])
        XCTAssertEqual(favorites[0].genreNames, ["Action"])
    }

    func test_load_whenStoreFails_setsFailedPersistence() async {
        let store = InMemoryFavoritesStore()
        await store.setLoadError(CocoaError(.fileReadUnknown))
        let viewModel = FavoritesListViewModel(
            favorites: FavoritesRepository(store: store, logger: SilentLogger())
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(.persistence))
    }

    func test_toggleFavorite_whenUnfavoriting_removesFromList() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Keep", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 2, title: "Remove", genreIDs: [28]),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        guard case .loaded(let before, _) = viewModel.state else {
            return XCTFail("Expected loaded before toggle")
        }
        let toRemove = before[0]
        await viewModel.toggleFavorite(toRemove)

        XCTAssertNil(viewModel.toggleError)
        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.id), [1])
        let stillFavorite = try await repository.isFavorite(id: 2, kind: .movie)
        XCTAssertFalse(stillFavorite)
    }

    func test_toggleFavorite_whenLastItemUnfavorited_setsEmpty() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 9, title: "Only", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        guard case .loaded(let before, _) = viewModel.state else {
            return XCTFail("Expected loaded before toggle")
        }
        await viewModel.toggleFavorite(before[0])

        XCTAssertNil(viewModel.toggleError)
        XCTAssertEqual(viewModel.state, .empty)
    }

    func test_removeFavorites_deletesRecordAndUpdatesState() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Keep", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 2, title: "Remove", genreIDs: [28]),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        await viewModel.removeFavorites(at: IndexSet(integer: 0))

        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.id), [1])
    }
}
