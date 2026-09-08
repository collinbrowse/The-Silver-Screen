//
//  MovieRepository.swift
//  URBNFlicks
//

import Foundation

struct MoviePage: Sendable, Equatable {
    let movies: [Movie]
    let page: Int
    let hasMore: Bool
}

final class MovieRepository: Sendable {
    private let client: any HTTPClient
    private let apiKey: String
    private let logger: any AppLogging
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    init(client: any HTTPClient, apiKey: String, logger: any AppLogging) {
        self.client = client
        self.apiKey = apiKey
        self.logger = logger
    }

    func topMovies(page: Int) async throws -> MoviePage {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("discover/movie"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "sort_by", value: "vote_average.desc"),
            URLQueryItem(name: "vote_count.gte", value: "200"),
            URLQueryItem(name: "without_genres", value: "99,10755"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "api_key", value: apiKey),
        ]

        guard let url = components.url else {
            throw AppError.unknown
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data = try await perform(request, context: "Top movies")

        do {
            let movies = try Self.decodeMovies(from: data, logger: logger)
            let pageMeta = try JSONDecoder().decode(MovieListPageMeta.self, from: data)
            return MoviePage(
                movies: movies,
                page: pageMeta.page,
                hasMore: pageMeta.page < pageMeta.totalPages
            )
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Top movies page metadata decode failed", category: .networking)
            throw AppError.decoding
        }
    }

    func movieDetail(id: Int) async throws -> MovieDetail {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("movie/\(id)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "api_key", value: apiKey),
        ]

        guard let url = components.url else {
            throw AppError.unknown
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data = try await perform(request, context: "Movie detail")

        do {
            let dto = try JSONDecoder().decode(MovieDetailDTO.self, from: data)
            return Self.map(dto)
        } catch let error as DecodingError {
            logger.error("Movie detail decode failed: \(error)", category: .networking)
            throw AppError.decoding
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Movie detail decode failed", category: .networking)
            throw AppError.decoding
        }
    }

    private func perform(_ request: URLRequest, context: String) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch let error as URLError {
            logger.error("\(context) request failed: \(error.code.rawValue)", category: .networking)
            throw Self.mapURLError(error)
        } catch {
            logger.error("\(context) request failed with unknown transport error", category: .networking)
            throw AppError.unknown
        }

        try Self.throwIfUnsuccessful(status: response.statusCode, logger: logger, context: context)
        return data
    }

    // MARK: - Mapping

    private static let releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func map(_ dto: MovieSummaryDTO) -> Movie {
        Movie(
            id: dto.id,
            title: dto.title,
            posterPath: dto.posterPath,
            releaseDate: parseReleaseDate(dto.releaseDate),
            voteAverage: dto.voteAverage,
            genreIDs: dto.genreIDs
        )
    }

    static func map(_ dto: MovieDetailDTO) -> MovieDetail {
        MovieDetail(
            id: dto.id,
            title: dto.title,
            overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            posterPath: dto.posterPath,
            releaseDate: parseReleaseDate(dto.releaseDate ?? ""),
            voteAverage: dto.voteAverage,
            genres: (dto.genres ?? []).map { MovieGenre(id: $0.id, name: $0.name) },
            budget: dto.budget ?? 0,
            revenue: dto.revenue ?? 0
        )
    }

    static func parseReleaseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return releaseDateFormatter.date(from: trimmed)
    }

    static func decodeMovies(from data: Data, logger: any AppLogging) throws -> [Movie] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [Any] else {
            throw AppError.decoding
        }

        let decoder = JSONDecoder()
        var movies: [Movie] = []
        var skipped = 0

        for element in results {
            do {
                let elementData = try JSONSerialization.data(withJSONObject: element)
                let dto = try decoder.decode(MovieSummaryDTO.self, from: elementData)
                movies.append(map(dto))
            } catch {
                skipped += 1
            }
        }

        if skipped > 0 {
            logger.error("Skipped \(skipped) malformed movie result(s)", category: .networking)
        }

        if movies.isEmpty, !results.isEmpty {
            throw AppError.decoding
        }

        return movies
    }

    private static func throwIfUnsuccessful(
        status: Int,
        logger: any AppLogging,
        context: String = "Request"
    ) throws {
        switch status {
        case 200..<300:
            return
        case 401, 403:
            logger.error("\(context) unauthorized status \(status)", category: .networking)
            throw AppError.unauthorized
        case 500..<600:
            logger.error("\(context) server status \(status)", category: .networking)
            throw AppError.server(status: status)
        default:
            logger.error("\(context) unexpected status \(status)", category: .networking)
            throw AppError.server(status: status)
        }
    }

    private static func mapURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .unknown
        }
    }
}

private struct MovieListPageMeta: Decodable {
    let page: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
    }
}
