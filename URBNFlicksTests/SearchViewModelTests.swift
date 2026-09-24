//
//  SearchViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class SearchViewModelTests: XCTestCase {

    func test_load_showsPopularMovies() async {
        let viewModel = makeViewModel(
            routes: ["movie/popular": .success(TMDBFixtures.topMoviesPage1)]
        )

        await viewModel.load()

        guard case .loaded(.movies(let rows), activity: .none) = viewModel.state else {
            return XCTFail("Expected popular movies, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.id), [278, 238])
        XCTAssertEqual(rows[0].genreNames, ["Drama", "Crime"])
    }

    func test_commitQueryChange_searchesMovies() async {
        let viewModel = makeViewModel(
            routes: [
                "movie/popular": .success(TMDBFixtures.topMoviesPage1),
                "search/movie": .success(TMDBFixtures.topMoviesPage2),
            ]
        )
        viewModel.query = "godfather"

        await viewModel.commitQueryChange()

        guard case .loaded(.movies(let rows), _) = viewModel.state else {
            return XCTFail("Expected search results, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.id), [240])
    }

    func test_keyboardDismissed_keepsSearchResults() async {
        let viewModel = makeViewModel(
            routes: ["search/movie": .success(TMDBFixtures.topMoviesPage2)]
        )
        viewModel.query = "godfather"
        await viewModel.commitQueryChange()
        let before = viewModel.state

        viewModel.keyboardDismissed()

        XCTAssertEqual(viewModel.state, before)
        XCTAssertEqual(viewModel.query, "godfather")
    }

    func test_scopeChange_loadsPopularTV() async {
        let viewModel = makeViewModel(
            routes: [
                "movie/popular": .success(TMDBFixtures.topMoviesPage1),
                "tv/popular": .success(TMDBFixtures.popularTVPage),
            ]
        )
        await viewModel.load()
        viewModel.scope = .tv

        await viewModel.reloadForScopeChange()

        guard case .loaded(.tv(let rows), _) = viewModel.state else {
            return XCTFail("Expected TV, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.name), ["Breaking Bad"])
        XCTAssertEqual(rows[0].genreNames, ["Drama", "Crime"])
        XCTAssertEqual(rows[0].formattedFirstAirDate, "Jan 20, 2008")
    }

    func test_peopleSearch_mapsKnownForDepartment() async {
        let viewModel = makeViewModel(
            routes: ["search/person": .success(TMDBFixtures.popularPeoplePage)]
        )
        viewModel.scope = .people
        viewModel.query = "pitt"

        await viewModel.commitQueryChange()

        guard case .loaded(.people(let rows), _) = viewModel.state else {
            return XCTFail("Expected people, got \(viewModel.state)")
        }
        XCTAssertEqual(rows[0].name, "Brad Pitt")
        XCTAssertEqual(rows[0].knownForDepartment, "Acting")
        XCTAssertEqual(rows[0].profilePath, "/pitt.jpg")
    }

    func test_loadMore_appendsSecondMoviePage() async {
        let client = SequencingHTTPClient(stubs: [
            .success(TMDBFixtures.topMoviesPage1),
            .success(TMDBFixtures.topMoviesPage2),
        ])
        let viewModel = SearchViewModel(
            movies: MovieRepository.test(client: client),
            shows: TVRepository.test(client: client),
            people: PersonRepository.test(client: client),
            sleeper: NoopSleeper()
        )

        await viewModel.load()
        await viewModel.loadMore()

        guard case .loaded(.movies(let rows), activity: .none) = viewModel.state else {
            return XCTFail("Expected paged movies, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.id), [278, 238, 240])
    }

    func test_submit_ignoresQueriesShorterThanTwoCharacters() async {
        let client = RoutingHTTPClient(routes: [
            "search/movie": .success(TMDBFixtures.topMoviesPage2),
        ])
        let viewModel = SearchViewModel(
            movies: MovieRepository.test(client: client),
            shows: TVRepository.test(client: client),
            people: PersonRepository.test(client: client),
            sleeper: NoopSleeper()
        )
        viewModel.query = "a"

        await viewModel.submit()

        let count = await client.requestCount
        XCTAssertEqual(count, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func test_scopeChange_reusesTheSegmentCache() async {
        let client = RoutingHTTPClient(routes: [
            "movie/popular": .success(TMDBFixtures.topMoviesPage1),
            "tv/popular": .success(TMDBFixtures.popularTVPage),
        ])
        let viewModel = SearchViewModel(
            movies: MovieRepository.test(client: client),
            shows: TVRepository.test(client: client),
            people: PersonRepository.test(client: client),
            sleeper: NoopSleeper()
        )
        await viewModel.load()
        viewModel.scope = .tv
        await viewModel.reloadForScopeChange()
        viewModel.scope = .movies
        await viewModel.reloadForScopeChange()

        let count = await client.requestCount
        XCTAssertEqual(count, 2)
        guard case .loaded(.movies(let rows), _) = viewModel.state else {
            return XCTFail("Expected the cached movie list")
        }
        XCTAssertEqual(rows.map(\.id), [278, 238])
        XCTAssertEqual(viewModel.query, "")
    }

    func test_emptyQuery_doesNotRefetchPopular() async {
        let client = RoutingHTTPClient(routes: [
            "movie/popular": .success(TMDBFixtures.topMoviesPage1),
            "search/movie": .success(TMDBFixtures.topMoviesPage2),
        ])
        let viewModel = SearchViewModel(
            movies: MovieRepository.test(client: client),
            shows: TVRepository.test(client: client),
            people: PersonRepository.test(client: client),
            sleeper: NoopSleeper()
        )
        await viewModel.load()
        viewModel.query = "godfather"
        await viewModel.submit()
        viewModel.query = "  "
        await viewModel.submit()

        let popularCount = await client.requests.filter { $0.url?.path.contains("movie/popular") == true }.count
        XCTAssertEqual(popularCount, 1)
        guard case .loaded(.movies(let rows), _) = viewModel.state else {
            return XCTFail("Expected popular movies back from the cache")
        }
        XCTAssertEqual(rows.map(\.id), [278, 238])
    }

    func test_submit_whileTheFieldIsFocusedAndEmpty_keepsThePlaceholder() async {
        let client = RoutingHTTPClient(routes: [
            "movie/popular": .success(TMDBFixtures.topMoviesPage1),
            "search/movie": .success(TMDBFixtures.topMoviesPage2),
        ])
        let viewModel = SearchViewModel(
            movies: MovieRepository.test(client: client),
            shows: TVRepository.test(client: client),
            people: PersonRepository.test(client: client),
            sleeper: NoopSleeper()
        )
        await viewModel.load()
        viewModel.query = "godfather"
        await viewModel.submit()
        viewModel.setFieldFocused(true)
        viewModel.query = ""
        await viewModel.submit()

        XCTAssertTrue(viewModel.showsFocusedPlaceholder)
        XCTAssertEqual(viewModel.state, .empty)

        viewModel.restoreAfterDismiss()

        guard case .loaded(.movies(let rows), _) = viewModel.state else {
            return XCTFail("Expected the search results back, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.id), [240])
        XCTAssertEqual(viewModel.query, "")
    }

    func test_focusedEmptyField_restoresTheLastResults() async {
        let viewModel = makeViewModel(
            routes: ["movie/popular": .success(TMDBFixtures.topMoviesPage1)]
        )
        await viewModel.load()
        let loaded = viewModel.state

        viewModel.setFieldFocused(true)

        XCTAssertTrue(viewModel.showsFocusedPlaceholder)
        XCTAssertEqual(viewModel.state, .empty)

        viewModel.restoreAfterDismiss()

        XCTAssertFalse(viewModel.showsFocusedPlaceholder)
        XCTAssertEqual(viewModel.state, loaded)
        XCTAssertEqual(viewModel.query, "")
    }

    func test_search_sendsIncludeAdultFalse() async throws {
        let client = RecordingHTTPClient(stub: .success(TMDBFixtures.popularTVPage))
        let shows = TVRepository.test(client: client)
        _ = try await shows.search(query: "bad", page: 1, locale: Locale(identifier: "en"))
        let tvItems = await queryItems(client)
        XCTAssertTrue(tvItems.contains(URLQueryItem(name: "include_adult", value: "false")))
        XCTAssertFalse(tvItems.contains { $0.name == "region" })

        let peopleClient = RecordingHTTPClient(stub: .success(TMDBFixtures.popularPeoplePage))
        let people = PersonRepository.test(client: peopleClient)
        _ = try await people.search(query: "pitt", page: 1, locale: Locale(identifier: "en_US"))
        let personItems = await queryItems(peopleClient)
        XCTAssertTrue(personItems.contains(URLQueryItem(name: "include_adult", value: "false")))
        XCTAssertTrue(personItems.contains(URLQueryItem(name: "language", value: "en-US")))
        XCTAssertTrue(personItems.contains(URLQueryItem(name: "region", value: "US")))
    }

    private func queryItems(_ client: RecordingHTTPClient) async -> [URLQueryItem] {
        let url = await client.lastURL
        return URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    private func makeViewModel(routes: [String: FakeHTTPClient.Stub]) -> SearchViewModel {
        let client = RoutingHTTPClient(routes: routes)
        return SearchViewModel(
            movies: MovieRepository.test(client: client),
            shows: TVRepository.test(client: client),
            people: PersonRepository.test(client: client),
            sleeper: NoopSleeper()
        )
    }
}
