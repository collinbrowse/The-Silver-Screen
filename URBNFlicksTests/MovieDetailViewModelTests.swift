//
//  MovieDetailViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class MovieDetailViewModelTests: XCTestCase {

    func test_load_whenClientSucceeds_setsLoadedContent() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.movieDetailShawshank))

        await viewModel.load()

        guard case .loaded(let content, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.detail.id, 278)
        XCTAssertEqual(content.detail.title, "The Shawshank Redemption")
        XCTAssertEqual(content.detail.overview, "Framed in the 1940s for a double murder.")
        XCTAssertEqual(content.detail.genres.map(\.name), ["Drama", "Crime"])
        XCTAssertEqual(content.formattedRating, "8.7 / 10")
        XCTAssertEqual(content.ratingAccessibilityLabel, "Rated 8.7 out of 10")
        XCTAssertEqual(content.formattedBudget, "$25.0M")
        XCTAssertEqual(content.formattedRevenue, "$28.3M")
        XCTAssertEqual(content.formattedReleaseDate, "Sep 23, 1994")
        XCTAssertEqual(content.images?.items.map(\.filePath), ["/backdrop-a.jpg", "/backdrop-b.jpg"])
        XCTAssertEqual(content.cast?.members.map(\.name), ["Tim Robbins", "Morgan Freeman"])
        XCTAssertEqual(content.crew?.people.count, 1)
        XCTAssertEqual(content.crew?.people.first?.name, "Frank Darabont")
        XCTAssertEqual(content.crew?.people.first?.roles, ["Director", "Screenplay"])
        XCTAssertEqual(content.similar?.items.map(\.id), [311])
        XCTAssertNil(content.collection)
        XCTAssertNil(content.reviews)
    }

    func test_load_whenNoImages_hidesImagesSection() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.movieDetailSparse))

        await viewModel.load()

        guard case .loaded(let content, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertNil(content.images)
        XCTAssertNil(content.cast)
        XCTAssertNil(content.crew)
        XCTAssertNil(content.similar)
    }

    func test_load_whenCollectionHasOtherParts_setsCollectionSection() async {
        let client = RoutingHTTPClient(routes: [
            "/movie/238": .success(TMDBFixtures.movieDetailWithCollection),
            "/collection/230": .success(TMDBFixtures.collectionGodfather),
            "/reviews": .success(TMDBFixtures.movieReviewsEmpty),
        ])
        let viewModel = MovieDetailViewModel(
            movieID: 238,
            movies: MovieRepository.test(client: client),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.collection?.title, "The Godfather Collection")
        XCTAssertEqual(content.collection?.movies.map(\.id), [240])
    }

    func test_load_whenCollectionOnlyContainsSelf_hidesCollectionSection() async {
        let client = RoutingHTTPClient(routes: [
            "/movie/238": .success(TMDBFixtures.movieDetailWithCollection),
            "/collection/230": .success(TMDBFixtures.collectionSolo),
            "/reviews": .success(TMDBFixtures.movieReviewsEmpty),
        ])
        let viewModel = MovieDetailViewModel(
            movieID: 238,
            movies: MovieRepository.test(client: client),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertNil(content.collection)
    }

    func test_load_whenReviewsExist_setsReviewsSection() async {
        let client = RoutingHTTPClient(routes: [
            "/movie/278": .success(TMDBFixtures.movieDetailShawshank),
            "/reviews": .success(TMDBFixtures.movieReviewsPage1),
        ])
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(client: client),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.reviews?.items.map(\.id), ["rev-1"])
        XCTAssertEqual(content.reviews?.items.first?.username, "alice_reviews")
        XCTAssertTrue(content.reviews?.hasMore == true)
    }

    func test_loadMoreReviews_appendsDedupedPage() async {
        let client = ReviewPagingHTTPClient()
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(client: client),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )

        await viewModel.load()
        await viewModel.loadMoreReviews()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.reviews?.items.map(\.id), ["rev-1", "rev-2"])
        XCTAssertEqual(content.reviews?.hasMore, false)
    }

    func test_openImages_setsFullscreenSelection() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.movieDetailShawshank))
        await viewModel.load()

        viewModel.openImages(initialID: "/backdrop-a.jpg")

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.fullscreenImages?.initialID, "/backdrop-a.jpg")
        XCTAssertEqual(content.fullscreenImages?.images.count, 2)
        XCTAssertEqual(content.fullscreenImages?.kind, .backdrop)

        viewModel.dismissImages()
        guard case .loaded(let dismissed, _) = viewModel.state else {
            return XCTFail("Expected loaded after dismiss")
        }
        XCTAssertNil(dismissed.fullscreenImages)
    }

    func test_openPoster_setsFullscreenPoster() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.movieDetailShawshank))
        await viewModel.load()

        viewModel.openPoster()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.fullscreenImages?.kind, .poster)
        XCTAssertEqual(content.fullscreenImages?.images.map(\.filePath), [content.detail.posterPath].compactMap { $0 })
        XCTAssertEqual(content.fullscreenImages?.images.count, 1)
    }

    func test_load_whenSparseDetail_formatsUnavailableFields() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.movieDetailSparse))

        await viewModel.load()

        guard case .loaded(let content, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.formattedBudget, "Not available")
        XCTAssertEqual(content.formattedRevenue, "Not available")
        XCTAssertEqual(content.formattedReleaseDate, "Not available")
        XCTAssertTrue(content.detail.genres.isEmpty)
    }

    func test_load_whenOffline_setsFailedOffline() async {
        let viewModel = makeViewModel(result: .failure(URLError(.notConnectedToInternet)))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(.offline))
    }

    func test_retry_afterFailure_loadsDetail() async {
        let switchable = SwitchableDetailHTTPClient(initial: .failure(URLError(.notConnectedToInternet)))
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(client: switchable),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.state, .failed(.offline))

        await switchable.setStub(.success(TMDBFixtures.movieDetailShawshank))
        await viewModel.retry()

        guard case .loaded(let content, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded after retry, got \(viewModel.state)")
        }
        XCTAssertEqual(content.detail.id, 278)
    }

    func test_toggleFavorite_updatesSharedIndex() async throws {
        let index = FavoritesIndex()
        let store = InMemoryFavoritesStore()
        let favorites = FavoritesRepository(store: store, logger: SilentLogger(), index: index)
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: favorites
        )
        await viewModel.load()

        await viewModel.toggleFavorite()

        guard case .loaded(_, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertTrue(index.contains(278, kind: .movie))
        let isFavorite = try await favorites.isFavorite(id: 278, kind: .movie)
        XCTAssertTrue(isFavorite)
        XCTAssertTrue(index.personIDs.isEmpty)
        XCTAssertEqual(index.movieIDs, [278])
    }

    func test_toggleFavorite_carouselMovie_updatesIndexWithoutFavoritingDetail() async throws {
        let index = FavoritesIndex()
        let favorites = FavoritesRepository(
            store: InMemoryFavoritesStore(),
            logger: SilentLogger(),
            index: index
        )
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: favorites
        )
        await viewModel.load()

        let similar = TestMovies.make(id: 311, title: "Similar", genreIDs: [18])
        await viewModel.toggleFavorite(movie: similar)

        guard case .loaded(_, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(index.movieIDs, [311])
        XCTAssertFalse(index.contains(278, kind: .movie))
        let similarFavorite = try await favorites.isFavorite(id: 311, kind: .movie)
        XCTAssertTrue(similarFavorite)
        let detailFavorite = try await favorites.isFavorite(id: 278, kind: .movie)
        XCTAssertFalse(detailFavorite)
    }

    func test_toggleFavoritePerson_updatesSharedIndexWithoutFavoritingMovie() async throws {
        let index = FavoritesIndex()
        let favorites = FavoritesRepository(
            store: InMemoryFavoritesStore(),
            logger: SilentLogger(),
            index: index
        )
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: favorites
        )
        await viewModel.load()

        await viewModel.toggleFavorite(
            person: FavoritePerson(
                id: 504,
                name: "Tim Robbins",
                profilePath: "/tim.jpg",
                knownForDepartment: "Acting"
            )
        )

        guard case .loaded(_, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertFalse(index.contains(278, kind: .movie))
        XCTAssertEqual(index.personIDs, [504])
        let isPersonFavorite = try await favorites.isFavorite(id: 504, kind: .person)
        XCTAssertTrue(isPersonFavorite)

        await viewModel.toggleFavorite(
            person: FavoritePerson(
                id: 504,
                name: "Tim Robbins",
                profilePath: "/tim.jpg",
                knownForDepartment: "Acting"
            )
        )

        guard case .loaded(_, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded after unfavorite, got \(viewModel.state)")
        }
        XCTAssertTrue(index.personIDs.isEmpty)
    }

    func test_toggleFavorite_movie_leavesFavoritePersonIDsUntouched() async throws {
        let index = FavoritesIndex()
        let favorites = FavoritesRepository(
            store: InMemoryFavoritesStore(),
            logger: SilentLogger(),
            index: index
        )
        _ = try await favorites.toggle(
            person: FavoritePerson(
                id: 504,
                name: "Tim Robbins",
                profilePath: "/tim.jpg",
                knownForDepartment: "Acting"
            ),
            favoritedAt: TestMovies.date("2024-01-01")
        )
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: favorites
        )
        await viewModel.load()

        XCTAssertEqual(index.personIDs, [504])

        await viewModel.toggleFavorite()

        guard case .loaded(_, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertTrue(index.contains(278, kind: .movie))
        XCTAssertEqual(index.personIDs, [504])
    }

    func test_toggleFavorite_whenPersistenceFails_keepsIndexAndSetsFailedActivity() async {
        let index = FavoritesIndex()
        let store = InMemoryFavoritesStore()
        await store.setSaveError(CocoaError(.fileWriteUnknown))
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: FavoritesRepository(store: store, logger: SilentLogger(), index: index)
        )
        await viewModel.load()

        await viewModel.toggleFavorite()

        guard case .loaded(let content, activity: .failed(let error)) = viewModel.state else {
            return XCTFail("Expected loaded with failed activity, got \(viewModel.state)")
        }
        XCTAssertEqual(content.detail.id, 278)
        XCTAssertFalse(index.contains(278, kind: .movie))
        XCTAssertEqual(error, .persistence)
    }

    func test_personToggleOnOtherScreen_updatesSharedIndexWithoutMovieReload() async throws {
        let index = FavoritesIndex()
        let favorites = FavoritesRepository(
            store: InMemoryFavoritesStore(),
            logger: SilentLogger(),
            index: index
        )
        let movieViewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: favorites
        )
        let personViewModel = PersonDetailViewModel(
            personID: 1922,
            people: PersonRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.personDetailMorganFreeman))
            ),
            favorites: favorites
        )
        await movieViewModel.load()
        await personViewModel.load()

        XCTAssertTrue(index.personIDs.isEmpty)

        await personViewModel.toggleFavorite()

        XCTAssertTrue(index.contains(1922, kind: .person))
        guard case .loaded = movieViewModel.state else {
            return XCTFail("Movie detail should stay loaded")
        }
    }

    func test_formatCurrency_zero_isNotAvailable() {
        let formatted = MovieDetailViewModel.formatCurrency(0)
        XCTAssertEqual(formatted.display, "Not available")
    }

    // MARK: - Helpers

    private func makeViewModel(stub: FakeHTTPClient.Stub) -> MovieDetailViewModel {
        MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(client: FakeHTTPClient(stub: stub)),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )
    }

    private func makeViewModel(result: Result<Data, Error>) -> MovieDetailViewModel {
        MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(client: FakeHTTPClient(result: result)),
            favorites: FavoritesRepository(store: InMemoryFavoritesStore(), logger: SilentLogger())
        )
    }
}

private actor SwitchableDetailHTTPClient: HTTPClient {
    private var stub: FakeHTTPClient.Stub

    init(initial: FakeHTTPClient.Stub) {
        self.stub = initial
    }

    func setStub(_ stub: FakeHTTPClient.Stub) {
        self.stub = stub
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await FakeHTTPClient(stub: stub).data(for: request)
    }
}

/// Detail + reviews page 1, then reviews page 2 for pagination.
private actor ReviewPagingHTTPClient: HTTPClient {
    private var reviewPage = 0

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        if path.contains("/reviews") {
            reviewPage += 1
            let stub: FakeHTTPClient.Stub = reviewPage == 1
                ? .success(TMDBFixtures.movieReviewsPage1)
                : .success(TMDBFixtures.movieReviewsPage2)
            return try await FakeHTTPClient(stub: stub).data(for: request)
        }
        return try await FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            .data(for: request)
    }
}
