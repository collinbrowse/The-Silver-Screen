//
//  MovieDetailDTO.swift
//  URBNFlicks
//

import Foundation

struct MovieGenreDTO: Decodable, Sendable {
    let id: Int
    let name: String
}

/// TMDB `/movie/{id}` payload fields needed for Story 1.
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
    }
}
