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
                URLQueryItem(name: "append_to_response", value: "credits,images,similar"),
                URLQueryItem(name: "include_image_language", value: "en,null"),
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
            return Self.map(dto, logger: logger)
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

    func collection(id: Int) async throws -> MovieCollection {
        let request = try requests.get(
            path: "collection/\(id)",
            queryItems: [
                URLQueryItem(name: "language", value: "en-US"),
            ]
        )

        let data = try await HTTPTransport.data(
            for: request,
            client: client,
            logger: logger,
            context: "Collection",
            sleeper: sleeper
        )

        do {
            let dto = try JSONDecoder().decode(MovieCollectionDTO.self, from: data)
            return MovieCollection(
                id: dto.id,
                name: dto.name,
                parts: (dto.parts ?? []).map(Self.map)
            )
        } catch let error as DecodingError {
            logger.error("Collection decode failed: \(error)", category: .networking)
            throw AppError.decoding
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Collection decode failed", category: .networking)
            throw AppError.decoding
        }
    }

    func movieReviews(id: Int, page: Int) async throws -> MovieReviewPage {
        let request = try requests.get(
            path: "movie/\(id)/reviews",
            queryItems: [
                URLQueryItem(name: "language", value: "en-US"),
                URLQueryItem(name: "page", value: String(page)),
            ]
        )

        let data = try await HTTPTransport.data(
            for: request,
            client: client,
            logger: logger,
            context: "Movie reviews",
            sleeper: sleeper
        )

        do {
            let dto = try JSONDecoder().decode(MovieReviewsPageDTO.self, from: data)
            let reviews = (dto.results ?? []).compactMap { Self.mapReview($0) }
            return MovieReviewPage(
                reviews: reviews,
                page: dto.page,
                hasMore: dto.page < dto.totalPages
            )
        } catch let error as DecodingError {
            logger.error("Movie reviews decode failed: \(error)", category: .networking)
            throw AppError.decoding
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Movie reviews decode failed", category: .networking)
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

    static func map(_ dto: MovieDetailDTO, logger: any AppLogging) -> MovieDetail {
        MovieDetail(
            id: dto.id,
            title: dto.title,
            overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            posterPath: dto.posterPath,
            releaseDate: parseReleaseDate(dto.releaseDate ?? ""),
            voteAverage: dto.voteAverage,
            genres: (dto.genres ?? []).map { MovieGenre(id: $0.id, name: $0.name) },
            budget: dto.budget ?? 0,
            revenue: dto.revenue ?? 0,
            images: mapImages(dto.images, logger: logger),
            cast: mapCast(dto.credits?.cast, logger: logger),
            crew: mapCrew(dto.credits?.crew, logger: logger),
            similar: mapSimilar(dto.similar?.results, logger: logger),
            collection: dto.belongsToCollection.map {
                MovieCollectionRef(id: $0.id, name: $0.name, posterPath: $0.posterPath)
            }
        )
    }

    static func mapImages(_ dto: MovieImagesDTO?, logger: any AppLogging) -> [MovieImage] {
        guard let backdrops = dto?.backdrops else { return [] }
        var images: [MovieImage] = []
        var skipped = 0
        for item in backdrops {
            let path = item.filePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                skipped += 1
                continue
            }
            images.append(MovieImage(filePath: path, voteAverage: item.voteAverage ?? 0))
        }
        if skipped > 0 {
            logger.error("Skipped \(skipped) malformed movie image(s)", category: .networking)
        }
        return images
            .sorted { $0.voteAverage > $1.voteAverage }
            .prefix(20)
            .map { $0 }
    }

    static func mapCast(_ items: [CastMemberDTO]?, logger: any AppLogging) -> [CastMember] {
        guard let items else { return [] }
        var cast: [CastMember] = []
        var skipped = 0
        for item in items {
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let creditID = item.creditID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !creditID.isEmpty else {
                skipped += 1
                continue
            }
            cast.append(
                CastMember(
                    id: creditID,
                    personID: item.id,
                    name: name,
                    character: item.character?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    profilePath: item.profilePath,
                    order: item.order ?? Int.max
                )
            )
        }
        if skipped > 0 {
            logger.error("Skipped \(skipped) malformed cast member(s)", category: .networking)
        }
        return cast
            .sorted { $0.order < $1.order }
            .prefix(20)
            .map { $0 }
    }

    static func mapCrew(_ items: [CrewMemberDTO]?, logger: any AppLogging) -> [CrewMember] {
        guard let items else { return [] }
        var crew: [CrewMember] = []
        var skipped = 0
        for item in items {
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let creditID = item.creditID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let job = item.job?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let department = item.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !creditID.isEmpty, !job.isEmpty else {
                skipped += 1
                continue
            }
            crew.append(
                CrewMember(
                    id: creditID,
                    personID: item.id,
                    name: name,
                    job: job,
                    department: department,
                    profilePath: item.profilePath
                )
            )
        }
        if skipped > 0 {
            logger.error("Skipped \(skipped) malformed crew member(s)", category: .networking)
        }
        return crew
    }

    /// Directors (`job == Director`) plus Writing department, deduped by person id.
    static func creditedDirectorsAndWriters(from crew: [CrewMember]) -> [CreditedPerson] {
        var byPerson: [Int: CreditedPerson] = [:]
        var order: [Int] = []

        func append(member: CrewMember, role: String) {
            if var existing = byPerson[member.personID] {
                if !existing.roles.contains(role) {
                    existing = CreditedPerson(
                        id: existing.id,
                        name: existing.name,
                        roles: existing.roles + [role],
                        profilePath: existing.profilePath ?? member.profilePath
                    )
                    byPerson[member.personID] = existing
                }
            } else {
                byPerson[member.personID] = CreditedPerson(
                    id: member.personID,
                    name: member.name,
                    roles: [role],
                    profilePath: member.profilePath
                )
                order.append(member.personID)
            }
        }

        for member in crew where member.job == "Director" {
            append(member: member, role: "Director")
        }
        for member in crew where member.department == "Writing" {
            append(member: member, role: member.job)
        }
        return order.compactMap { byPerson[$0] }
    }

    static func mapSimilar(_ items: [MovieSummaryDTO]?, logger: any AppLogging) -> [Movie] {
        guard let items else { return [] }
        var movies: [Movie] = []
        var skipped = 0
        var seen = Set<Int>()
        for item in items {
            let movie = map(item)
            guard seen.insert(movie.id).inserted else {
                skipped += 1
                continue
            }
            movies.append(movie)
            if movies.count == 20 { break }
        }
        if skipped > 0 {
            logger.error("Skipped \(skipped) duplicate similar movie(s)", category: .networking)
        }
        return movies
    }

    static func mapReview(_ dto: MovieReviewDTO) -> MovieReview? {
        let content = dto.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { return nil }
        let author = dto.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Anonymous"
        let username = dto.authorDetails?.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? author
        return MovieReview(
            id: dto.id,
            author: author,
            username: username,
            content: content,
            updatedAt: parseReviewDate(dto.updatedAt)
        )
    }

    static func parseReleaseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return releaseDateFormatter.date(from: trimmed)
    }

    static func parseReviewDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: trimmed) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: trimmed)
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
