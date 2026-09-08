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
    private let requests: TMDBRequestBuilder
    private let logger: any AppLogging
    private let sleeper: any Sleeper

    init(
        client: any HTTPClient,
        apiKey: String,
        logger: any AppLogging,
        sleeper: any Sleeper = TaskSleeper()
    ) {
        self.client = client
        self.requests = TMDBRequestBuilder(apiKey: apiKey)
        self.logger = logger
        self.sleeper = sleeper
    }

    func topMovies(page: Int) async throws -> MoviePage {
        let request = try requests.get(
            path: "discover/movie",
            queryItems: [
                URLQueryItem(name: "language", value: "en-US"),
                URLQueryItem(name: "sort_by", value: "vote_average.desc"),
                URLQueryItem(name: "vote_count.gte", value: "200"),
                URLQueryItem(name: "without_genres", value: "99,10755"),
                URLQueryItem(name: "page", value: String(page)),
            ]
        )

        let data = try await HTTPTransport.data(
            for: request,
            client: client,
            logger: logger,
            context: "Top movies",
            sleeper: sleeper
        )

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
        let request = try requests.get(
            path: "movie/\(id)",
            queryItems: [
                URLQueryItem(name: "language", value: "en-US"),
            ]
        )

        let data = try await HTTPTransport.data(
            for: request,
            client: client,
            logger: logger,
            context: "Movie detail",
            sleeper: sleeper
        )

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
}

private struct MovieListPageMeta: Decodable {
    let page: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
    }
}
