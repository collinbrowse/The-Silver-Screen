//
//  MovieListViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class MovieListViewModelTests: XCTestCase {

    func test_load_whenClientSucceeds_setsLoadedState() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.topMoviesPage1))

        await viewModel.load()

        guard case .loaded(let movies, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.count, 2)
        XCTAssertEqual(movies[0].id, 278)
    }

    func test_load_whenResultsEmpty_setsEmptyState() async {
        let empty = Data(
            """
            {"page":1,"results":[],"total_pages":1,"total_results":0}
            """.utf8
        )
        let viewModel = makeViewModel(stub: .success(empty))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .empty)
    }

    func test_load_whenOffline_setsFailedOffline() async {
        let viewModel = makeViewModel(result: .failure(URLError(.notConnectedToInternet)))

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(.offline))
    }

    func test_refresh_whenOffline_keepsContentWithFailedActivity() async {
        let switchable = SwitchableHTTPClient(initial: .success(TMDBFixtures.topMoviesPage1))
        let vm = MovieListViewModel(
            movies: MovieRepository(client: switchable, apiKey: "test", logger: SilentLogger())
        )
        await vm.load()
        await switchable.setStub(.failure(URLError(.notConnectedToInternet)))

        await vm.refresh()

        guard case .loaded(let movies, activity: .failed(let error)) = vm.state else {
            return XCTFail("Expected loaded with failed activity, got \(vm.state)")
        }
        XCTAssertEqual(movies.count, 2)
        XCTAssertEqual(error, .offline)
    }

    func test_retry_afterFailure_loadsMovies() async {
        let switchable = SwitchableHTTPClient(initial: .failure(URLError(.notConnectedToInternet)))
        let viewModel = MovieListViewModel(
            movies: MovieRepository(client: switchable, apiKey: "test", logger: SilentLogger())
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.state, .failed(.offline))

        await switchable.setStub(.success(TMDBFixtures.topMoviesPage1))
        await viewModel.retry()

        guard case .loaded(let movies, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded after retry, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.count, 2)
    }

    func test_setSortOption_alphabetical_reordersWithoutRefetch() async {
        let client = CountingHTTPClient(stub: .success(TMDBFixtures.topMoviesPage1))
        let viewModel = MovieListViewModel(
            movies: MovieRepository(client: client, apiKey: "test", logger: SilentLogger())
        )
        await viewModel.load()
        let countAfterLoad = await client.requestCount
        XCTAssertEqual(countAfterLoad, 1)

        viewModel.setSortOption(.alphabetical)

        guard case .loaded(let movies, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.map(\.title), ["The Godfather", "The Shawshank Redemption"])
        let countAfterSort = await client.requestCount
        XCTAssertEqual(countAfterSort, 1)
        XCTAssertEqual(viewModel.sortOption, .alphabetical)
    }

    func test_setSortOption_yearNewestFirst_ordersDatesAndPutsNilLast() async {
        let json = Data(
            """
            {
              "page": 1,
              "results": [
                {"id":1,"title":"Old","poster_path":null,"release_date":"1972-03-14","vote_average":8.0},
                {"id":2,"title":"New","poster_path":null,"release_date":"1994-09-23","vote_average":8.0},
                {"id":3,"title":"Unknown","poster_path":null,"release_date":"","vote_average":8.0}
              ],
              "total_pages": 1,
              "total_results": 3
            }
            """.utf8
        )
        let viewModel = makeViewModel(stub: .success(json))
        await viewModel.load()

        viewModel.setSortOption(.yearNewestFirst)

        guard case .loaded(let movies, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.map(\.title), ["New", "Old", "Unknown"])
    }

    func test_setSortOption_yearOldestFirst_ordersAscending() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.topMoviesPage1))
        await viewModel.load()

        viewModel.setSortOption(.yearOldestFirst)

        guard case .loaded(let movies, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.map(\.title), ["The Godfather", "The Shawshank Redemption"])
    }

    // MARK: - Helpers

    private func makeViewModel(stub: FakeHTTPClient.Stub) -> MovieListViewModel {
        MovieListViewModel(
            movies: MovieRepository(
                client: FakeHTTPClient(stub: stub),
                apiKey: "test",
                logger: SilentLogger()
            )
        )
    }

    private func makeViewModel(result: Result<Data, Error>) -> MovieListViewModel {
        MovieListViewModel(
            movies: MovieRepository(
                client: FakeHTTPClient(result: result),
                apiKey: "test",
                logger: SilentLogger()
            )
        )
    }
}

private actor SwitchableHTTPClient: HTTPClient {
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

private actor CountingHTTPClient: HTTPClient {
    private let stub: FakeHTTPClient.Stub
    private(set) var requestCount = 0

    init(stub: FakeHTTPClient.Stub) {
        self.stub = stub
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        return try await FakeHTTPClient(stub: stub).data(for: request)
    }
}
