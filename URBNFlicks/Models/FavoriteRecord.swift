//
//  FavoriteRecord.swift
//  URBNFlicks
//

import Foundation

enum FavoriteKind: String, Codable, Sendable, Equatable {
    case movie
    case tv
    case person
}

struct FavoriteRecord: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let kind: FavoriteKind
    let favoritedAt: Date
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let genreNames: [String]

    /// Stable per-kind identity for SwiftUI lists; TMDB movie and person ids share a namespace
    /// (movie 500 is Reservoir Dogs, person 500 is Tom Cruise) and would collide in a ForEach.
    var listID: String { "\(kind.rawValue)-\(id)" }

    /// Domain movie used to open the shared detail screen. Only valid for `.movie` records.
    func asMovie(voteAverage: Double = 0) -> Movie {
        precondition(kind == .movie, "asMovie() requires a movie favorite")
        return Movie(
            id: id,
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            genreIDs: MovieGenreCatalog.ids(for: genreNames)
        )
    }
}
