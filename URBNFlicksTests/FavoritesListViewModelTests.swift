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

    func test_load_mixedMovieAndPerson_sortsNewestFirst() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 500, title: "Reservoir Dogs", genreIDs: [80]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(
                id: 500,
                name: "Tom Cruise",
                profilePath: "/cruise.jpg",
                knownForDepartment: "Acting"
            ),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)

        await viewModel.load()

        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.listID), ["person-500", "movie-500"])
        XCTAssertEqual(favorites[0].genreNames, ["Acting"])
    }

    func test_toggleFavorite_person_leavesSameIDMovieIntact() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 500, title: "Reservoir Dogs", genreIDs: [80]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(
                id: 500,
                name: "Tom Cruise",
                profilePath: "/cruise.jpg",
                knownForDepartment: "Acting"
            ),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        guard case .loaded(let before, _) = viewModel.state else {
            return XCTFail("Expected loaded before toggle")
        }
        let person = before.first { $0.kind == .person }!
        await viewModel.toggleFavorite(person)

        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.listID), ["movie-500"])
        let movieStillFavorite = try await repository.isFavorite(id: 500, kind: .movie)
        XCTAssertTrue(movieStillFavorite)
        let personStillFavorite = try await repository.isFavorite(id: 500, kind: .person)
        XCTAssertFalse(personStillFavorite)
    }

    func test_displayedFavorites_filtersByKind() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            tv: FavoriteTVSeries(id: 3, name: "Series", posterPath: nil, releaseDate: nil, genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-03-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 2, name: "Person", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        viewModel.filter = .all
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["person-2", "tv-3", "movie-1"])

        viewModel.filter = .movies
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["movie-1"])

        viewModel.filter = .tvSeries
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["tv-3"])

        viewModel.filter = .people
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["person-2"])
    }

    func test_displayedFavorites_searchRespectsTVFilter() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            tv: FavoriteTVSeries(id: 1, name: "Breaking Bad", posterPath: nil, releaseDate: nil, genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 2, title: "Breaking Point", genreIDs: [28]),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .tvSeries
        viewModel.searchText = "breaking"

        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["tv-1"])
    }

    func test_removeFavorites_underTVFilter_deletesDisplayedSeries() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            tv: FavoriteTVSeries(id: 2, name: "Series", posterPath: nil, releaseDate: nil, genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .tvSeries

        await viewModel.removeFavorites(at: IndexSet(integer: 0))

        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.listID), ["movie-1"])
        let tvGone = try await repository.isFavorite(id: 2, kind: .tv)
        XCTAssertFalse(tvGone)
    }

    func test_displayedFavorites_whenFilterYieldsEmpty_keepsLoadedState() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        viewModel.filter = .people

        guard case .loaded = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertTrue(viewModel.displayedFavorites.isEmpty)
    }

    func test_removeFavorites_underPeopleFilter_deletesDisplayedPerson() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 2, name: "Person", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .people

        await viewModel.removeFavorites(at: IndexSet(integer: 0))

        guard case .loaded(let favorites, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(favorites.map(\.listID), ["movie-1"])
        let personGone = try await repository.isFavorite(id: 2, kind: .person)
        XCTAssertFalse(personGone)
    }

    func test_load_preservesActiveFilter() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .movies

        await viewModel.load()

        XCTAssertEqual(viewModel.filter, .movies)
    }

    func test_displayedFavorites_searchMatchesTitleCaseInsensitive() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Reservoir Dogs", genreIDs: [80]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 2, name: "Tom Cruise", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()

        viewModel.searchText = "reservoir"
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["movie-1"])

        viewModel.searchText = "CRUISE"
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["person-2"])
    }

    func test_displayedFavorites_searchRespectsMoviesFilter() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Léon: The Professional", genreIDs: [28]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 2, name: "Léon", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .movies
        viewModel.searchText = "Léon"

        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["movie-1"])
    }

    func test_displayedFavorites_searchRespectsPeopleFilter() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Léon: The Professional", genreIDs: [28]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 2, name: "Léon", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .people
        viewModel.searchText = "Léon"

        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["person-2"])
    }

    func test_displayedFavorites_clearingSearchRestoresFilteredSet() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        _ = try await repository.toggle(
            person: FavoritePerson(id: 2, name: "Person", profilePath: nil, knownForDepartment: "Acting"),
            favoritedAt: TestMovies.date("2024-06-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.filter = .people
        viewModel.searchText = "zzz"
        XCTAssertTrue(viewModel.displayedFavorites.isEmpty)

        viewModel.searchText = ""
        XCTAssertEqual(viewModel.displayedFavorites.map(\.listID), ["person-2"])
    }

    func test_load_preservesSearchText() async throws {
        let store = InMemoryFavoritesStore()
        let repository = FavoritesRepository(store: store, logger: SilentLogger())
        _ = try await repository.toggle(
            movie: TestMovies.make(id: 1, title: "Movie", genreIDs: [18]),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        let viewModel = FavoritesListViewModel(favorites: repository)
        await viewModel.load()
        viewModel.searchText = "Movie"

        await viewModel.load()

        XCTAssertEqual(viewModel.searchText, "Movie")
    }
}
