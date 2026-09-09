//
//  MovieCollection.swift
//  URBNFlicks
//

import Foundation

struct MovieCollectionRef: Sendable, Equatable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
}

struct MovieCollection: Sendable, Equatable, Hashable {
    let id: Int
    let name: String
    let parts: [Movie]
}
