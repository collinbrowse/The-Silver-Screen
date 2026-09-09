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
            movies: MovieRepository.test(client: switchable)
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
            movies: MovieRepository.test(client: switchable)
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
            movies: MovieRepository.test(client: client)
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

    func test_loadMore_appendsNextPageAndClearsLoadingMore() async {
        let client = PagingHTTPClient(pages: [
            1: TMDBFixtures.topMoviesPage1,
            2: TMDBFixtures.topMoviesPage2,
        ])
        let viewModel = MovieListViewModel(movies: MovieRepository.test(client: client))
        await viewModel.load()

        await viewModel.loadMore()

        guard case .loaded(let movies, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded with no activity, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.map(\.id), [278, 238, 240])
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func test_loadMore_whileAlreadyPaging_isIgnored() async {
        let client = GateablePagingHTTPClient(
            page1: TMDBFixtures.topMoviesPage1,
            page2: TMDBFixtures.topMoviesPage2
        )
        let viewModel = MovieListViewModel(movies: MovieRepository.test(client: client))
        await viewModel.load()

        async let first: Void = viewModel.loadMore()
        await client.waitUntilPage2Started()
        await viewModel.loadMore()
        await client.releasePage2()
        await first

        guard case .loaded(let movies, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.map(\.id), [278, 238, 240])
        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func test_hasMore_whenFinalPageArrives_stopsReportingMorePages() async {
        let client = PagingHTTPClient(pages: [
            1: TMDBFixtures.topMoviesPage1,
            2: TMDBFixtures.topMoviesPage2,
        ])
        let viewModel = MovieListViewModel(movies: MovieRepository.test(client: client))
        await viewModel.load()
        XCTAssertTrue(viewModel.hasMore)

        await viewModel.loadMore()

        XCTAssertFalse(viewModel.hasMore)
    }

    func test_loadMore_afterFinalPage_doesNotRequestAgain() async {
        let client = PagingHTTPClient(pages: [
            1: TMDBFixtures.topMoviesPage1,
            2: TMDBFixtures.topMoviesPage2,
        ])
        let viewModel = MovieListViewModel(movies: MovieRepository.test(client: client))
        await viewModel.load()
        await viewModel.loadMore()
        let requestsAfterLastPage = await client.requestCount

        await viewModel.loadMore()

        let requestsAfterExtraCall = await client.requestCount
        XCTAssertEqual(requestsAfterExtraCall, requestsAfterLastPage)
    }

    func test_hasMore_whenOnlyOnePageExists_isFalseAfterLoad() async {
        let viewModel = makeViewModel(stub: .success(TMDBFixtures.topMoviesWithEmptyReleaseDate))

        await viewModel.load()

        XCTAssertFalse(viewModel.hasMore)
    }

    func test_loadMore_keepsContentOnScreenWhilePageIsInFlight() async {
        let client = GateablePagingHTTPClient(
            page1: TMDBFixtures.topMoviesPage1,
            page2: TMDBFixtures.topMoviesPage2
        )
        let viewModel = MovieListViewModel(movies: MovieRepository.test(client: client))
        await viewModel.load()

        async let paging: Void = viewModel.loadMore()
        await client.waitUntilPage2Started()

        guard case .loaded(let movies, activity: .loadingMore) = viewModel.state else {
            return XCTFail("Expected loaded with loadingMore activity, got \(viewModel.state)")
        }
        XCTAssertEqual(movies.count, 2)

        await client.releasePage2()
        await paging
    }

    // MARK: - Helpers

    private func makeViewModel(stub: FakeHTTPClient.Stub) -> MovieListViewModel {
        MovieListViewModel(
            movies: MovieRepository.test(client: FakeHTTPClient(stub: stub))
        )
    }

    private func makeViewModel(result: Result<Data, Error>) -> MovieListViewModel {
        MovieListViewModel(
            movies: MovieRepository.test(client: FakeHTTPClient(result: result))
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

/// Returns fixture JSON keyed by the `page` query item.
private actor PagingHTTPClient: HTTPClient {
    private let pages: [Int: Data]
    private(set) var requestCount = 0

    init(pages: [Int: Data]) {
        self.pages = pages
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        let page = pageNumber(from: request) ?? 1
        guard let data = pages[page] else {
            throw URLError(.badServerResponse)
        }
        return try await FakeHTTPClient(stub: .success(data)).data(for: request)
    }

    private func pageNumber(from request: URLRequest) -> Int? {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "page" })?.value else {
            return nil
        }
        return Int(value)
    }
}

/// Holds page 2 until released so overlapping `loadMore` calls can be asserted.
private actor GateablePagingHTTPClient: HTTPClient {
    private let page1: Data
    private let page2: Data
    private(set) var requestCount = 0
    private var page2Started: CheckedContinuation<Void, Never>?
    private var page2Gate: CheckedContinuation<Void, Never>?
    private var waitingForRelease = false

    init(page1: Data, page2: Data) {
        self.page1 = page1
        self.page2 = page2
    }

    func waitUntilPage2Started() async {
        if waitingForRelease { return }
        await withCheckedContinuation { continuation in
            page2Started = continuation
        }
    }

    func releasePage2() {
        page2Gate?.resume()
        page2Gate = nil
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        let page = pageNumber(from: request) ?? 1
        if page == 1 {
            return try await FakeHTTPClient(stub: .success(page1)).data(for: request)
        }

        waitingForRelease = true
        page2Started?.resume()
        page2Started = nil
        await withCheckedContinuation { continuation in
            page2Gate = continuation
        }
        waitingForRelease = false
        return try await FakeHTTPClient(stub: .success(page2)).data(for: request)
    }

    private func pageNumber(from request: URLRequest) -> Int? {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "page" })?.value else {
            return nil
        }
        return Int(value)
    }
}
