//
//  TVSeriesDTO.swift
//  URBNFlicks
//
//  TMDB payloads for series, season, and episode detail. Internal to the data layer.
//

import Foundation

struct TVSeriesSummaryDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let posterPath: String?
    let firstAirDate: String?
    let genreIDs: [Int]?
    let voteAverage: Double?
    let popularity: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
        case genreIDs = "genre_ids"
        case voteAverage = "vote_average"
        case popularity
    }
}

struct TVCreatorDTO: Decodable, Sendable {
    let id: Int
    let name: String?
}

struct TVSeasonSummaryDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let seasonNumber: Int
    let episodeCount: Int?
    let airDate: String?
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
        case posterPath = "poster_path"
    }
}

struct TVAggregateRoleDTO: Decodable, Sendable {
    let character: String?
    let episodeCount: Int?

    enum CodingKeys: String, CodingKey {
        case character
        case episodeCount = "episode_count"
    }
}

struct TVAggregateJobDTO: Decodable, Sendable {
    let job: String?
    let episodeCount: Int?

    enum CodingKeys: String, CodingKey {
        case job
        case episodeCount = "episode_count"
    }
}

struct TVAggregateCastDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let profilePath: String?
    let knownForDepartment: String?
    let totalEpisodeCount: Int?
    let roles: [TVAggregateRoleDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
        case totalEpisodeCount = "total_episode_count"
        case roles
    }
}

struct TVAggregateCrewDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let profilePath: String?
    let department: String?
    let knownForDepartment: String?
    let totalEpisodeCount: Int?
    let jobs: [TVAggregateJobDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profilePath = "profile_path"
        case department
        case knownForDepartment = "known_for_department"
        case totalEpisodeCount = "total_episode_count"
        case jobs
    }
}

struct TVAggregateCreditsDTO: Decodable, Sendable {
    let cast: [TVAggregateCastDTO]?
    let crew: [TVAggregateCrewDTO]?
}

struct TVSeriesResultsDTO: Decodable, Sendable {
    let results: [TVSeriesSummaryDTO]?
}

struct TVSeriesDetailDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let genres: [MovieGenreDTO]?
    let createdBy: [TVCreatorDTO]?
    let seasons: [TVSeasonSummaryDTO]?
    let images: MovieImagesDTO?
    let aggregateCredits: TVAggregateCreditsDTO?
    let recommendations: TVSeriesResultsDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case genres
        case createdBy = "created_by"
        case seasons
        case images
        case aggregateCredits = "aggregate_credits"
        case recommendations
    }
}

struct TVEpisodeSummaryDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let overview: String?
    let episodeNumber: Int
    let airDate: String?
    let stillPath: String?
    let crew: [CrewMemberDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
        case crew
    }
}

struct TVSeasonDetailDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let overview: String?
    let seasonNumber: Int
    let airDate: String?
    let posterPath: String?
    let episodes: [TVEpisodeSummaryDTO]?
    let images: MovieImagesDTO?
    let aggregateCredits: TVAggregateCreditsDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case seasonNumber = "season_number"
        case airDate = "air_date"
        case posterPath = "poster_path"
        case episodes
        case images
        case aggregateCredits = "aggregate_credits"
    }
}

struct TVEpisodeCreditsDTO: Decodable, Sendable {
    let cast: [CastMemberDTO]?
    let crew: [CrewMemberDTO]?
    let guestStars: [CastMemberDTO]?

    enum CodingKeys: String, CodingKey {
        case cast
        case crew
        case guestStars = "guest_stars"
    }
}

struct TVEpisodeDetailDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let overview: String?
    let episodeNumber: Int
    let airDate: String?
    let stillPath: String?
    let crew: [CrewMemberDTO]?
    let guestStars: [CastMemberDTO]?
    let credits: TVEpisodeCreditsDTO?
    let images: MovieImagesDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
        case crew
        case guestStars = "guest_stars"
        case credits
        case images
    }
}

struct PersonSummaryDTO: Decodable, Sendable {
    let id: Int
    let name: String?
    let profilePath: String?
    let knownForDepartment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}
