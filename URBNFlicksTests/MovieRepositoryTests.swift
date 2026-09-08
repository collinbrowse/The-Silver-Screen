//
//  MovieRepositoryTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

final class MovieRepositoryTests: XCTestCase {

    func test_topMovies_mapsFixtureToDomainMovies() async throws {
        let client = FakeHTTPClient(stub: .success(TMDBFixtures.topMoviesPage1, status: 200))
        let repository = MovieRepository.test(client: client)

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 2)
        XCTAssertEqual(page.movies[0].id, 278)
        XCTAssertEqual(page.movies[0].title, "The Shawshank Redemption")
        XCTAssertEqual(page.movies[0].posterPath, "/poster.jpg")
        XCTAssertEqual(page.movies[0].releaseDate, TestMovies.date("1994-09-23"))
        XCTAssertEqual(page.movies[0].voteAverage, 8.7, accuracy: 0.01)
        XCTAssertEqual(page.movies[0].genreIDs, [18, 80])
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.page, 1)
    }

    func test_topMovies_emptyReleaseDate_mapsToNilAndKeepsMovie() async throws {
        let client = FakeHTTPClient(stub: .success(TMDBFixtures.topMoviesWithEmptyReleaseDate))
        let repository = MovieRepository.test(client: client)

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 1)
        XCTAssertNil(page.movies[0].releaseDate)
        XCTAssertEqual(page.movies[0].title, "Untitled")
        XCTAssertFalse(page.hasMore)
    }

    func test_topMovies_whenOffline_throwsOffline() async {
        let client = FakeHTTPClient(result: .failure(URLError(.notConnectedToInternet)))
        let repository = MovieRepository.test(client: client)

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
        let repository = MovieRepository.test(client: client)

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_topMovies_whenUnauthorized_doesNotRetry() async {
        let client = SequencingHTTPClient(stubs: [
            .success(Data(), status: 401),
            .success(TMDBFixtures.topMoviesPage1),
        ])
        let repository = MovieRepository.test(client: client)

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }

        let count = await client.requestCount
        XCTAssertEqual(count, 1)
    }

    func test_topMovies_whenServerError_throwsServerStatus() async {
        let client = FakeHTTPClient(stub: .success(Data(), status: 500))
        let repository = MovieRepository.test(client: client)

        do {
            _ = try await repository.topMovies(page: 1)
            XCTFail("Expected server error")
        } catch let error as AppError {
            XCTAssertEqual(error, .server(status: 500))
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_topMovies_whenServerErrorThenSuccess_retriesAndReturns() async throws {
        let client = SequencingHTTPClient(stubs: [
            .success(Data(), status: 500),
            .success(Data(), status: 503),
            .success(TMDBFixtures.topMoviesPage1),
        ])
        let repository = MovieRepository.test(client: client)

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 2)
        let count = await client.requestCount
        XCTAssertEqual(count, 3)
    }

    func test_topMovies_whenOfflineThenSuccess_retriesAndReturns() async throws {
        let client = SequencingHTTPClient(stubs: [
            .failure(URLError(.notConnectedToInternet)),
            .success(TMDBFixtures.topMoviesPage1),
        ])
        let repository = MovieRepository.test(client: client)

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 2)
        let count = await client.requestCount
        XCTAssertEqual(count, 2)
    }

    func test_topMovies_whenGarbageJSON_throwsDecoding() async {
        let client = FakeHTTPClient(stub: .success(Data("not-json".utf8)))
        let repository = MovieRepository.test(client: client)

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
        let repository = MovieRepository.test(client: client)

        let page = try await repository.topMovies(page: 1)

        XCTAssertEqual(page.movies.count, 1)
        XCTAssertEqual(page.movies[0].title, "Good")
    }

    func test_movieDetail_requestsApiKeyAndMapsFields() async throws {
        let client = RecordingHTTPClient(stub: .success(TMDBFixtures.movieDetailShawshank))
        let repository = MovieRepository.test(client: client, apiKey: "test-key")

        let detail = try await repository.movieDetail(id: 278)

        XCTAssertEqual(detail.id, 278)
        XCTAssertEqual(detail.title, "The Shawshank Redemption")
        XCTAssertEqual(detail.overview, "Framed in the 1940s for a double murder.")
        XCTAssertEqual(detail.posterPath, "/poster.jpg")
        XCTAssertEqual(detail.releaseDate, TestMovies.date("1994-09-23"))
        XCTAssertEqual(detail.voteAverage, 8.7, accuracy: 0.01)
        XCTAssertEqual(detail.budget, 25_000_000)
        XCTAssertEqual(detail.revenue, 28_341_469)
        XCTAssertEqual(detail.genres.map(\.name), ["Drama", "Crime"])

        let path = await client.lastPath
        XCTAssertEqual(path, "/3/movie/278")
        let url = await client.lastURL
        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "api_key", value: "test-key")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "language", value: "en-US")))
        let authorization = await client.lastAuthorizationHeader
        XCTAssertNil(authorization)
    }

    func test_movieDetail_emptyReleaseDateAndZeroMoney_mapsCleanly() async throws {
        let client = FakeHTTPClient(stub: .success(TMDBFixtures.movieDetailSparse))
        let repository = MovieRepository.test(client: client)

        let detail = try await repository.movieDetail(id: 999)

        XCTAssertNil(detail.releaseDate)
        XCTAssertNil(detail.posterPath)
        XCTAssertEqual(detail.budget, 0)
        XCTAssertEqual(detail.revenue, 0)
        XCTAssertTrue(detail.genres.isEmpty)
        XCTAssertEqual(detail.overview, "")
    }

    func test_movieDetail_whenOffline_throwsOffline() async {
        let client = FakeHTTPClient(result: .failure(URLError(.notConnectedToInternet)))
        let repository = MovieRepository.test(client: client)

        do {
            _ = try await repository.movieDetail(id: 278)
            XCTFail("Expected offline error")
        } catch let error as AppError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_movieDetail_whenUnauthorized_throwsUnauthorized() async {
        let client = FakeHTTPClient(stub: .success(Data(), status: 401))
        let repository = MovieRepository.test(client: client)

        do {
            _ = try await repository.movieDetail(id: 278)
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }

    func test_movieDetail_whenGarbageJSON_throwsDecoding() async {
        let client = FakeHTTPClient(stub: .success(Data("not-json".utf8)))
        let repository = MovieRepository.test(client: client)

        do {
            _ = try await repository.movieDetail(id: 278)
            XCTFail("Expected decoding error")
        } catch let error as AppError {
            XCTAssertEqual(error, .decoding)
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }
    }
}
