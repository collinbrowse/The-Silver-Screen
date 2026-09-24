//
//  TVRepository.swift
//  URBNFlicks
//
//  TV series, season, and episode reads. Mapping, paging, and AppError
//  translation stay here so screens never see a DTO.
//

import Foundation

final class TVRepository: Sendable {
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

    /// One Discover page, already sorted. Browse merges this with the movie stream.
    func discover(
        sort: BrowseSort,
        window: BrowseWindow,
        page: Int,
        locale: Locale = .current,
        today: Date = Date()
    ) async throws -> TVSeriesPage {
        try await fetch(
            path: DiscoverKind.tv.path,
            context: "Browse TV",
            queryItems: DiscoverQuery.items(
                kind: .tv,
                sort: sort,
                window: window,
                page: page,
                locale: locale,
                today: today
            )
        ) { data in
            let decoded = try TMDBPageDecoding.decode(
                TVSeriesSummaryDTO.self,
                from: data,
                logger: logger,
                context: "Browse TV"
            )
            let series = decoded.items.compactMap { Self.mapSummary($0) }
            if series.isEmpty, !decoded.items.isEmpty {
                throw AppError.decoding
            }
            return TVSeriesPage(
                series: series,
                page: decoded.page,
                hasMore: decoded.page < decoded.totalPages
            )
        }
    }

    func popular(page: Int, locale: Locale = .current) async throws -> TVSeriesPage {
        try await fetchSeriesPage(
            path: "tv/popular",
            context: "Popular TV",
            page: page,
            extra: [],
            locale: locale
        )
    }

    func search(query: String, page: Int, locale: Locale = .current) async throws -> TVSeriesPage {
        try await fetchSeriesPage(
            path: "search/tv",
            context: "TV search",
            page: page,
            extra: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "include_adult", value: "false"),
            ],
            locale: locale
        )
    }

    /// Series detail with images, aggregate credits, and recommendations appended.
    /// Language follows the device. Appended sections decode on their own so one bad row
    /// cannot fail the screen.
    func series(id: Int, locale: Locale = .current) async throws -> TVSeriesDetail {
        try await fetch(
            path: "tv/\(id)",
            context: "TV series",
            queryItems: [
                URLQueryItem(name: "language", value: TMDBLocale.languageTag(for: locale)),
                URLQueryItem(name: "append_to_response", value: "images,aggregate_credits,recommendations"),
                URLQueryItem(name: "include_image_language", value: "en,null"),
            ]
        ) { data in
            try Self.decodeSeries(data, logger: logger)
        }
    }

    func season(seriesID: Int, seasonNumber: Int, locale: Locale = .current) async throws -> TVSeasonDetail {
        try await fetch(
            path: "tv/\(seriesID)/season/\(seasonNumber)",
            context: "TV season",
            queryItems: [
                URLQueryItem(name: "language", value: TMDBLocale.languageTag(for: locale)),
                URLQueryItem(name: "append_to_response", value: "images,aggregate_credits"),
            ]
        ) { data in
            try Self.decodeSeason(data, logger: logger)
        }
    }

    func episode(
        seriesID: Int,
        seasonNumber: Int,
        episodeNumber: Int,
        locale: Locale = .current
    ) async throws -> TVEpisodeDetail {
        try await fetch(
            path: "tv/\(seriesID)/season/\(seasonNumber)/episode/\(episodeNumber)",
            context: "TV episode",
            queryItems: [
                URLQueryItem(name: "language", value: TMDBLocale.languageTag(for: locale)),
                URLQueryItem(name: "append_to_response", value: "images,credits"),
            ]
        ) { data in
            try Self.decodeEpisode(data, logger: logger)
        }
    }

    func reviews(seriesID: Int, page: Int) async throws -> MovieReviewPage {
        try await fetch(
            path: "tv/\(seriesID)/reviews",
            context: "TV reviews",
            queryItems: [
                URLQueryItem(name: "language", value: "en-US"),
                URLQueryItem(name: "page", value: String(page)),
            ]
        ) { data in
            let dto = try JSONDecoder().decode(MovieReviewsPageDTO.self, from: data)
            let reviews = (dto.results ?? []).compactMap { MovieRepository.mapReview($0) }
            return MovieReviewPage(
                reviews: reviews,
                page: dto.page,
                hasMore: dto.page < dto.totalPages,
                totalCount: dto.totalResults ?? reviews.count
            )
        }
    }

    // MARK: - Transport

    private func fetchSeriesPage(
        path: String,
        context: String,
        page: Int,
        extra: [URLQueryItem],
        locale: Locale? = nil
    ) async throws -> TVSeriesPage {
        let queryItems = locale.map {
            TMDBLocale.queryItems(locale: $0, page: page, extra: extra)
        } ?? extra + [
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        return try await fetch(
            path: path,
            context: context,
            queryItems: queryItems
        ) { data in
            let decoded = try TMDBPageDecoding.decode(
                TVSeriesSummaryDTO.self,
                from: data,
                logger: logger,
                context: context
            )
            let series = decoded.items.compactMap { Self.mapSummary($0) }
            if series.isEmpty, !decoded.items.isEmpty {
                throw AppError.decoding
            }
            return TVSeriesPage(
                series: series,
                page: decoded.page,
                hasMore: decoded.page < decoded.totalPages
            )
        }
    }

    private func fetch<T: Sendable>(
        path: String,
        context: String,
        queryItems: [URLQueryItem],
        map: (Data) throws -> T
    ) async throws -> T {
        let request = try requests.get(path: path, queryItems: queryItems)
        let data = try await HTTPTransport.data(
            for: request,
            client: client,
            logger: logger,
            context: context,
            sleeper: sleeper
        )
        do {
            return try map(data)
        } catch let error as DecodingError {
            logger.error("\(context) decode failed: \(error)", category: .networking)
            throw AppError.decoding
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("\(context) decode failed", category: .networking)
            throw AppError.decoding
        }
    }

    // MARK: - Appended sections

    /// Core fields still fail the screen. Images, credits, and recommendations are decoded
    /// apart from that payload so one bad element is skipped instead.
    private static func decodeSeries(_ data: Data, logger: any AppLogging) throws -> TVSeriesDetail {
        let split = try splitAppended(data, keys: ["images", "aggregate_credits", "recommendations"])
        let dto = try JSONDecoder().decode(TVSeriesDetailDTO.self, from: split.core)
        let images = imageSection(split.sections["images"], preferredKey: "backdrops", logger: logger, context: "series images")
        let credits = aggregateSection(split.sections["aggregate_credits"], logger: logger)
        let recommendations = recommendationSection(
            split.sections["recommendations"],
            excludingID: dto.id,
            logger: logger
        )
        return mapSeries(
            dto,
            logger: logger,
            images: images,
            recommendations: recommendations,
            cast: credits.cast,
            directorsAndWriters: credits.crew
        )
    }

    private static func decodeSeason(_ data: Data, logger: any AppLogging) throws -> TVSeasonDetail {
        let split = try splitAppended(data, keys: ["images", "aggregate_credits"])
        let dto = try JSONDecoder().decode(TVSeasonDetailDTO.self, from: split.core)
        let images = imageSection(split.sections["images"], preferredKey: "stills", fallbackKey: "posters", logger: logger, context: "season images")
        let credits = aggregateSection(split.sections["aggregate_credits"], logger: logger)
        return mapSeason(
            dto,
            logger: logger,
            images: images,
            cast: credits.cast,
            directorsAndWriters: credits.crew
        )
    }

    private static func decodeEpisode(_ data: Data, logger: any AppLogging) throws -> TVEpisodeDetail {
        let split = try splitAppended(data, keys: ["images", "credits"])
        let dto = try JSONDecoder().decode(TVEpisodeDetailDTO.self, from: split.core)
        let images = imageSection(split.sections["images"], preferredKey: "stills", logger: logger, context: "episode images")
        let credits = episodeCreditSection(split.sections["credits"], logger: logger)
        let guests = credits.guestStars.isEmpty ? (dto.guestStars ?? []) : credits.guestStars
        let crew = credits.crew.isEmpty ? (dto.crew ?? []) : credits.crew
        return mapEpisode(
            dto,
            logger: logger,
            images: images,
            cast: credits.cast,
            guestStars: guests,
            crew: crew
        )
    }

    private static func splitAppended(
        _ data: Data,
        keys: [String]
    ) throws -> (core: Data, sections: [String: Any]) {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.decoding
        }
        var sections: [String: Any] = [:]
        for key in keys {
            if let value = root.removeValue(forKey: key) {
                sections[key] = value
            }
        }
        let core = try JSONSerialization.data(withJSONObject: root)
        return (core, sections)
    }

    private static func imageSection(
        _ value: Any?,
        preferredKey: String,
        fallbackKey: String? = nil,
        logger: any AppLogging,
        context: String
    ) -> [MovieImage] {
        guard let value else { return [] }
        guard let dict = value as? [String: Any] else {
            logger.error("\(context) was not an object", category: .networking)
            return []
        }
        if let raw = dict[preferredKey] {
            let items = TMDBPageDecoding.elements(MovieImageDTO.self, from: raw, logger: logger, context: context)
            return MovieRepository.mapImageItems(items, logger: logger)
        }
        if let fallbackKey, let raw = dict[fallbackKey] {
            let items = TMDBPageDecoding.elements(MovieImageDTO.self, from: raw, logger: logger, context: context)
            return MovieRepository.mapImageItems(items, logger: logger)
        }
        return []
    }

    private static func aggregateSection(
        _ value: Any?,
        logger: any AppLogging
    ) -> (cast: [TVCredit], crew: [TVCredit]) {
        guard let value else { return ([], []) }
        guard let dict = value as? [String: Any] else {
            logger.error("Aggregate credits were not an object", category: .networking)
            return ([], [])
        }
        let cast = TMDBPageDecoding.elements(
            TVAggregateCastDTO.self,
            from: dict["cast"],
            logger: logger,
            context: "aggregate cast"
        )
        let crew = TMDBPageDecoding.elements(
            TVAggregateCrewDTO.self,
            from: dict["crew"],
            logger: logger,
            context: "aggregate crew"
        )
        return (
            mapAggregateCast(cast, logger: logger),
            mapAggregateCrew(crew, logger: logger)
        )
    }

    private static func recommendationSection(
        _ value: Any?,
        excludingID: Int,
        logger: any AppLogging
    ) -> [TVSeriesSummary] {
        guard let value else { return [] }
        guard let dict = value as? [String: Any] else {
            logger.error("Recommendations were not an object", category: .networking)
            return []
        }
        let items = TMDBPageDecoding.elements(
            TVSeriesSummaryDTO.self,
            from: dict["results"],
            logger: logger,
            context: "recommendations"
        )
        return items
            .compactMap(mapSummary)
            .filter { $0.id != excludingID }
            .prefix(20)
            .map { $0 }
    }

    private static func episodeCreditSection(
        _ value: Any?,
        logger: any AppLogging
    ) -> (cast: [CastMemberDTO], guestStars: [CastMemberDTO], crew: [CrewMemberDTO]) {
        guard let value else { return ([], [], []) }
        guard let dict = value as? [String: Any] else {
            logger.error("Episode credits were not an object", category: .networking)
            return ([], [], [])
        }
        return (
            TMDBPageDecoding.elements(CastMemberDTO.self, from: dict["cast"], logger: logger, context: "episode cast"),
            TMDBPageDecoding.elements(CastMemberDTO.self, from: dict["guest_stars"], logger: logger, context: "guest stars"),
            TMDBPageDecoding.elements(CrewMemberDTO.self, from: dict["crew"], logger: logger, context: "episode crew")
        )
    }

    // MARK: - Mapping

    static func mapSummary(_ dto: TVSeriesSummaryDTO) -> TVSeriesSummary? {
        let name = dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return nil }
        return TVSeriesSummary(
            id: dto.id,
            name: name,
            posterPath: dto.posterPath,
            firstAirDate: MovieRepository.parseReleaseDate(dto.firstAirDate ?? ""),
            genreIDs: dto.genreIDs ?? [],
            voteAverage: dto.voteAverage ?? 0,
            popularity: dto.popularity ?? 0
        )
    }

    static func mapSeries(
        _ dto: TVSeriesDetailDTO,
        logger: any AppLogging,
        images: [MovieImage],
        recommendations: [TVSeriesSummary],
        cast: [TVCredit],
        directorsAndWriters: [TVCredit]
    ) -> TVSeriesDetail {
        let creators = (dto.createdBy ?? []).compactMap { creator -> String? in
            let name = creator.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? nil : name
        }
        let seasons = (dto.seasons ?? [])
            .map { mapSeasonSummary($0) }
            .sorted { $0.seasonNumber < $1.seasonNumber }
        return TVSeriesDetail(
            id: dto.id,
            name: dto.name.trimmingCharacters(in: .whitespacesAndNewlines),
            overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            posterPath: dto.posterPath,
            firstAirDate: MovieRepository.parseReleaseDate(dto.firstAirDate ?? ""),
            lastAirDate: MovieRepository.parseReleaseDate(dto.lastAirDate ?? ""),
            genres: (dto.genres ?? []).map { MovieGenre(id: $0.id, name: $0.name) },
            creators: creators,
            images: images,
            seasons: seasons,
            recommendations: recommendations,
            cast: cast,
            directorsAndWriters: directorsAndWriters
        )
    }

    static func mapSeason(
        _ dto: TVSeasonDetailDTO,
        logger: any AppLogging,
        images: [MovieImage],
        cast: [TVCredit],
        directorsAndWriters: [TVCredit]
    ) -> TVSeasonDetail {
        let episodes = (dto.episodes ?? [])
            .sorted { $0.episodeNumber < $1.episodeNumber }
            .map { mapEpisodeSummary($0, logger: logger) }
        return TVSeasonDetail(
            id: dto.id,
            name: dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            seasonNumber: dto.seasonNumber,
            overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            airDate: MovieRepository.parseReleaseDate(dto.airDate ?? ""),
            posterPath: dto.posterPath,
            images: images,
            cast: cast,
            directorsAndWriters: directorsAndWriters,
            episodes: episodes
        )
    }

    static func mapEpisode(
        _ dto: TVEpisodeDetailDTO,
        logger: any AppLogging,
        images: [MovieImage],
        cast: [CastMemberDTO],
        guestStars: [CastMemberDTO],
        crew: [CrewMemberDTO]
    ) -> TVEpisodeDetail {
        TVEpisodeDetail(
            id: dto.id,
            title: dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            episodeNumber: dto.episodeNumber,
            overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            airDate: MovieRepository.parseReleaseDate(dto.airDate ?? ""),
            stillPath: dto.stillPath,
            images: images,
            cast: mapEpisodePeople(cast, logger: logger, context: "episode cast"),
            guestStars: mapEpisodePeople(guestStars, logger: logger, context: "guest stars"),
            directorsAndWriters: mapEpisodeCrew(crew, logger: logger)
        )
    }

    /// Cast with a real episode count, highest first, then name. At most 30 people.
    static func mapAggregateCast(
        _ items: [TVAggregateCastDTO]?,
        logger: any AppLogging
    ) -> [TVCredit] {
        guard let items else { return [] }
        var credits: [TVCredit] = []
        var seen = Set<Int>()
        var skipped = 0
        for item in items {
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, seen.insert(item.id).inserted else {
                skipped += 1
                continue
            }
            let character = (item.roles ?? [])
                .sorted { ($0.episodeCount ?? 0) > ($1.episodeCount ?? 0) }
                .compactMap { role -> String? in
                    let value = role.character?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return value.isEmpty ? nil : value
                }
                .first ?? ""
            let knownFor = trimmed(item.knownForDepartment)
            credits.append(
                TVCredit(
                    id: item.id,
                    name: name,
                    role: character,
                    profilePath: item.profilePath,
                    episodeCount: item.totalEpisodeCount ?? 0,
                    knownForDepartment: knownFor
                )
            )
        }
        if skipped > 0 {
            logger.error("Skipped \(skipped) malformed aggregate cast credit(s)", category: .networking)
        }
        return rankedByEpisodeCount(credits)
    }

    /// Directors and writing-department crew with a real episode count, then name. At most 30.
    static func mapAggregateCrew(
        _ items: [TVAggregateCrewDTO]?,
        logger: any AppLogging
    ) -> [TVCredit] {
        guard let items else { return [] }
        var byPerson: [Int: TVCredit] = [:]
        var skipped = 0
        for item in items {
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                skipped += 1
                continue
            }
            let roles = directorAndWriterRoles(department: item.department, jobs: item.jobs ?? [])
            guard !roles.isEmpty else { continue }
            let credit = TVCredit(
                id: item.id,
                name: name,
                role: roles.joined(separator: ", "),
                profilePath: item.profilePath,
                episodeCount: item.totalEpisodeCount ?? 0,
                knownForDepartment: trimmed(item.knownForDepartment)
            )
            if let existing = byPerson[item.id] {
                let mergedRoles = mergeRoles(existing.role, credit.role)
                byPerson[item.id] = TVCredit(
                    id: item.id,
                    name: existing.name,
                    role: mergedRoles,
                    profilePath: existing.profilePath ?? credit.profilePath,
                    episodeCount: max(existing.episodeCount, credit.episodeCount),
                    knownForDepartment: existing.knownForDepartment ?? credit.knownForDepartment
                )
            } else {
                byPerson[item.id] = credit
            }
        }
        if skipped > 0 {
            logger.error("Skipped \(skipped) malformed aggregate crew credit(s)", category: .networking)
        }
        return rankedByEpisodeCount(Array(byPerson.values))
    }

    private static func mapSeasonSummary(_ dto: TVSeasonSummaryDTO) -> TVSeasonSummary {
        TVSeasonSummary(
            id: dto.id,
            name: dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            seasonNumber: dto.seasonNumber,
            episodeCount: dto.episodeCount ?? 0,
            airDate: MovieRepository.parseReleaseDate(dto.airDate ?? ""),
            posterPath: dto.posterPath
        )
    }

    private static func mapEpisodeSummary(
        _ dto: TVEpisodeSummaryDTO,
        logger: any AppLogging
    ) -> TVEpisodeSummary {
        let crew = MovieRepository.mapCrew(dto.crew, logger: logger)
        let directors = crew.filter { $0.job == "Director" }.map(\.name)
        let director = directors.isEmpty ? nil : directors.joined(separator: ", ")
        return TVEpisodeSummary(
            id: dto.id,
            title: dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            episodeNumber: dto.episodeNumber,
            overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            airDate: MovieRepository.parseReleaseDate(dto.airDate ?? ""),
            stillPath: dto.stillPath,
            directorName: director
        )
    }

    private static func mapEpisodePeople(
        _ items: [CastMemberDTO],
        logger: any AppLogging,
        context: String
    ) -> [TVCredit] {
        let members = MovieRepository.mapCast(items, logger: logger)
        var seen = Set<Int>()
        var credits: [TVCredit] = []
        for member in members where seen.insert(member.personID).inserted {
            credits.append(
                TVCredit(
                    id: member.personID,
                    name: member.name,
                    role: member.character,
                    profilePath: member.profilePath,
                    episodeCount: 0,
                    knownForDepartment: member.knownForDepartment
                )
            )
            if credits.count == 30 { break }
        }
        if members.count > credits.count {
            logger.error("Capped \(context) at 30 people", category: .networking)
        }
        return credits
    }

    /// Episode crew is only Director, Writer, and Screenplay. Other writing jobs stay off the list.
    private static func mapEpisodeCrew(
        _ items: [CrewMemberDTO],
        logger: any AppLogging
    ) -> [TVCredit] {
        let allowed: Set<String> = ["Director", "Writer", "Screenplay"]
        let crew = MovieRepository.mapCrew(items, logger: logger).filter { allowed.contains($0.job) }
        var rolesByPerson: [Int: [String]] = [:]
        var creditByPerson: [Int: TVCredit] = [:]
        var order: [Int] = []
        for member in crew {
            if rolesByPerson[member.personID] == nil {
                order.append(member.personID)
                rolesByPerson[member.personID] = [member.job]
                creditByPerson[member.personID] = TVCredit(
                    id: member.personID,
                    name: member.name,
                    role: member.job,
                    profilePath: member.profilePath,
                    episodeCount: 0,
                    knownForDepartment: member.knownForDepartment
                )
            } else if rolesByPerson[member.personID]?.contains(member.job) == false {
                rolesByPerson[member.personID, default: []].append(member.job)
            }
        }
        return order.prefix(30).compactMap { id in
            guard let credit = creditByPerson[id], let roles = rolesByPerson[id] else { return nil }
            return TVCredit(
                id: credit.id,
                name: credit.name,
                role: roles.joined(separator: ", "),
                profilePath: credit.profilePath,
                episodeCount: 0,
                knownForDepartment: credit.knownForDepartment
            )
        }
    }

    /// Drops people who never appeared, then orders by count, name, and id.
    private static func rankedByEpisodeCount(_ credits: [TVCredit]) -> [TVCredit] {
        Array(
            credits
                .filter { $0.episodeCount > 0 }
                .sorted(by: byEpisodeCountThenName)
                .prefix(30)
        )
    }

    private static func byEpisodeCountThenName(_ lhs: TVCredit, _ rhs: TVCredit) -> Bool {
        if lhs.episodeCount != rhs.episodeCount {
            return lhs.episodeCount > rhs.episodeCount
        }
        let order = lhs.name.localizedStandardCompare(rhs.name)
        if order != .orderedSame {
            return order == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func directorAndWriterRoles(
        department: String?,
        jobs: [TVAggregateJobDTO]
    ) -> [String] {
        var roles: [String] = []
        let departmentName = department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if jobs.contains(where: { $0.job == "Director" }) {
            roles.append("Director")
        }
        if departmentName == "Writing" {
            for job in jobs {
                let title = job.job?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty, title != "Director", !roles.contains(title) else { continue }
                roles.append(title)
            }
            if roles.isEmpty {
                roles.append("Writer")
            }
        }
        return roles
    }

    private static func mergeRoles(_ lhs: String, _ rhs: String) -> String {
        var roles = lhs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for role in rhs.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !roles.contains(role) {
            roles.append(role)
        }
        return roles.joined(separator: ", ")
    }

    private static func trimmed(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
