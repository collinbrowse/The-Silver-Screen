//
//  MovieCatalogViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class MovieCatalogViewModelTests: XCTestCase {

    func test_load_nowPlaying_setsRowsWithGenresAndDate() async {
        let viewModel = MovieCatalogViewModel(
            kind: .nowPlaying,
            movies: MovieRepository.test(client: FakeHTTPClient(stub: .success(TMDBFixtures.topMoviesPage1)))
        )

        await viewModel.load()

        guard case .loaded(let rows, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.title), ["The Shawshank Redemption", "The Godfather"])
        XCTAssertEqual(rows[0].genreNames, ["Drama", "Crime"])
        XCTAssertEqual(rows[0].formattedReleaseDate, "Sep 23, 1994")
        XCTAssertEqual(viewModel.title, "Now Playing")
    }

    func test_load_upcoming_requestsUpcoming() async {
        let client = RecordingHTTPClient(stub: .success(TMDBFixtures.topMoviesPage1))
        let viewModel = MovieCatalogViewModel(
            kind: .upcoming,
            movies: MovieRepository.test(client: client)
        )

        await viewModel.load()

        let path = await client.lastPath
        XCTAssertEqual(path, "/3/movie/upcoming")
        guard case .loaded(let rows, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.count, 2)
    }

    func test_loadMore_appendsNextPageWithoutDuplicates() async {
        let client = SequencingHTTPClient(stubs: [
            .success(TMDBFixtures.topMoviesPage1),
            .success(TMDBFixtures.topMoviesPage2),
        ])
        let viewModel = MovieCatalogViewModel(
            kind: .nowPlaying,
            movies: MovieRepository.test(client: client)
        )

        await viewModel.load()
        await viewModel.loadMore()

        guard case .loaded(let rows, activity: .none) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.id), [278, 238, 240])
    }

    func test_load_whenOffline_setsFailed() async {
        let viewModel = MovieCatalogViewModel(
            kind: .nowPlaying,
            movies: MovieRepository.test(
                client: FakeHTTPClient(result: .failure(URLError(.notConnectedToInternet)))
            )
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(.offline))
    }
}
