//
//  Movie.swift
//  URBNFlicks
//

import Foundation

struct Movie: Sendable, Identifiable, Hashable {
    let id: Int
    let title: String
    let posterPath: String?
    let releaseDate: Date?
    let voteAverage: Double
    let genreIDs: [Int]
}
