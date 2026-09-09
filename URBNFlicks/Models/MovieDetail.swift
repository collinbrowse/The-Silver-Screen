//
//  MovieDetail.swift
//  URBNFlicks
//

import Foundation

struct MovieGenre: Sendable, Equatable, Hashable, Identifiable {
    let id: Int
    let name: String
}

struct MovieDetail: Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let releaseDate: Date?
    let voteAverage: Double
    let genres: [MovieGenre]
    let budget: Int
    let revenue: Int
    let images: [MovieImage]
    let cast: [CastMember]
    let crew: [CrewMember]
    let similar: [Movie]
    let collection: MovieCollectionRef?

    /// Summary used when toggling favorites from detail.
    func asMovie() -> Movie {
        Movie(
            id: id,
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            genreIDs: genres.map(\.id)
        )
    }
}
