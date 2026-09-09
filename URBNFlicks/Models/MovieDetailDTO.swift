//
//  MovieDetailDTO.swift
//  URBNFlicks
//

import Foundation

struct MovieGenreDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

struct MovieImageDTO: Decodable, Sendable {
    let filePath: String
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case voteAverage = "vote_average"
    }
}

struct MovieImagesDTO: Decodable, Sendable {
    let backdrops: [MovieImageDTO]?
    let posters: [MovieImageDTO]?
}

struct CastMemberDTO: Decodable, Sendable {
    let id: Int
    let creditID: String?
    let name: String?
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case creditID = "credit_id"
        case name
        case character
        case profilePath = "profile_path"
        case order
    }
}

struct CrewMemberDTO: Decodable, Sendable {
    let id: Int
    let creditID: String?
    let name: String?
    let job: String?
    let department: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creditID = "credit_id"
        case name
        case job
        case department
        case profilePath = "profile_path"
    }
}

struct MovieCreditsDTO: Decodable, Sendable {
    let cast: [CastMemberDTO]?
    let crew: [CrewMemberDTO]?
}

struct MovieCollectionRefDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case posterPath = "poster_path"
    }
}

struct MovieCollectionDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let parts: [MovieSummaryDTO]?
}

struct MovieReviewAuthorDTO: Decodable, Sendable {
    let username: String?
}

struct MovieReviewDTO: Decodable, Sendable {
    let id: String
    let author: String?
    let content: String?
    let updatedAt: String?
    let authorDetails: MovieReviewAuthorDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case content
        case updatedAt = "updated_at"
        case authorDetails = "author_details"
    }
}

struct MovieReviewsPageDTO: Decodable, Sendable {
    let page: Int
    let totalPages: Int
    let results: [MovieReviewDTO]?

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
        case results
    }
}

/// TMDB `/movie/{id}` payload, including optional `append_to_response` sections.
struct MovieDetailDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let genres: [MovieGenreDTO]?
    let budget: Int?
    let revenue: Int?
    let images: MovieImagesDTO?
    let credits: MovieCreditsDTO?
    let similar: MovieListResultsDTO?
    let belongsToCollection: MovieCollectionRefDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case genres
        case budget
        case revenue
        case images
        case credits
        case similar
        case belongsToCollection = "belongs_to_collection"
    }
}

struct MovieListResultsDTO: Decodable, Sendable {
    let results: [MovieSummaryDTO]?
}
