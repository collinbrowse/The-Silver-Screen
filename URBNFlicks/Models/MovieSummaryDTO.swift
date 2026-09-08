//
//  MovieSummaryDTO.swift
//  URBNFlicks
//

import Foundation

struct MovieListDTO: Decodable, Sendable {
    let page: Int
    let results: [MovieSummaryDTO]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// Decodes one TMDB movie result element. Kept internal to the data layer.
struct MovieSummaryDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let posterPath: String?
    let releaseDate: String
    let voteAverage: Double

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}
