//
//  FavoriteRecord.swift
//  URBNFlicks
//

import Foundation

enum FavoriteKind: String, Codable, Sendable, Equatable {
    case movie
}

struct FavoriteRecord: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let kind: FavoriteKind
    let favoritedAt: Date
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let genreNames: [String]

    /// Domain movie used to open the shared detail screen.
    func asMovie(voteAverage: Double = 0) -> Movie {
        Movie(
            id: id,
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            genreIDs: MovieGenreCatalog.ids(for: genreNames)
        )
    }
}
