//
//  MovieRepositoryTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

final class MovieRepositoryTests: XCTestCase {

    func test_topMovies_mapsFixtureToDomainMovies() async throws {
        let client = FakeHTTPClient(stub: .success(TMDBFixtures.topMoviesPage1, status: 200))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 2)
        XCTAssertEqual(page.movies[0].id, 278)
        XCTAssertEqual(page.movies[0].title, "The Shawshank Redemption")
        XCTAssertEqual(page.movies[0].posterPath, "/poster.jpg")
        XCTAssertEqual(page.movies[0].releaseDate, TestMovies.date("1994-09-23"))
        XCTAssertEqual(page.movies[0].voteAverage, 8.7, accuracy: 0.01)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.page, 1)
    }

    func test_topMovies_emptyReleaseDate_mapsToNilAndKeepsMovie() async throws {
        let client = FakeHTTPClient(stub: .success(TMDBFixtures.topMoviesWithEmptyReleaseDate))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 1)
        XCTAssertNil(page.movies[0].releaseDate)
        XCTAssertEqual(page.movies[0].title, "Untitled")
        XCTAssertFalse(page.hasMore)
    }

    func test_topMovies_whenOffline_throwsOffline() async {
        let client = FakeHTTPClient(result: .failure(URLError(.notConnectedToInternet)))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected offline error")
        } catch let error as AppError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_topMovies_whenUnauthorized_throwsUnauthorized() async {
        let client = FakeHTTPClient(stub: .success(Data(), status: 401))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_topMovies_whenServerError_throwsServerStatus() async {
        let client = FakeHTTPClient(stub: .success(Data(), status: 500))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected server error")
        } catch let error as AppError {
            XCTAssertEqual(error, .server(status: 500))
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_topMovies_whenGarbageJSON_throwsDecoding() async {
        let client = FakeHTTPClient(stub: .success(Data("not-json".utf8)))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected decoding error")
        } catch let error as AppError {
            XCTAssertEqual(error, .decoding)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_topMovies_skipsMalformedElement_keepsValidOnes() async throws {
        let json = Data(
            """
            {
              "page": 1,
              "results": [
                {
                  "id": 1,
                  "title": "Good",
                  "poster_path": null,
                  "release_date": "2000-01-01",
                  "vote_average": 7.5
                },
                {
                  "id": "bad",
                  "title": 12
                }
              ],
              "total_pages": 1,
              "total_results": 2
            }
            """.utf8
        )
        let client = FakeHTTPClient(stub: .success(json))
        let repository = MovieRepository(client: client, apiKey: "test", logger: SilentLogger())

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 1)
        XCTAssertEqual(page.movies[0].title, "Good")
    }
}
