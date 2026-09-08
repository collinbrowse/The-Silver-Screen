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
        XCTAssertFalse(content.isFavorite)
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

    func test_toggleFavorite_updatesFavoriteFlag() async throws {
        let store = InMemoryFavoritesStore()
        let favorites = FavoritesRepository(store: store, logger: SilentLogger())
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: favorites
        )
        await viewModel.load()

        await viewModel.toggleFavorite()

        guard case .loaded(let content, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertTrue(content.isFavorite)
        let isFavorite = try await favorites.isFavorite(id: 278)
        XCTAssertTrue(isFavorite)
    }

    func test_toggleFavorite_whenPersistenceFails_keepsContentWithFailedActivity() async {
        let store = InMemoryFavoritesStore()
        await store.setSaveError(CocoaError(.fileWriteUnknown))
        let viewModel = MovieDetailViewModel(
            movieID: 278,
            movies: MovieRepository.test(
                client: FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
            ),
            favorites: FavoritesRepository(store: store, logger: SilentLogger())
        )
        await viewModel.load()

        await viewModel.toggleFavorite()

        guard case .loaded(let content, activity: .failed(let error)) = viewModel.state else {
            return XCTFail("Expected loaded with failed activity, got \(viewModel.state)")
        }
        XCTAssertEqual(content.detail.id, 278)
        XCTAssertFalse(content.isFavorite)
        XCTAssertEqual(error, .persistence)
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
