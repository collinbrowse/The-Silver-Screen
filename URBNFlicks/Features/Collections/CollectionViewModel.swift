//
//  CollectionViewModel.swift
//  URBNFlicks
//

import Foundation

struct CollectionContent: Sendable, Equatable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let parts: [CatalogMovieRow]
}

/// Loads one movie collection: header plus the parts list.
@Observable
@MainActor
final class CollectionViewModel {
    private(set) var state: LoadState<CollectionContent> = .idle

    private let collectionID: Int
    private let movies: MovieRepository

    init(collectionID: Int, movies: MovieRepository) {
        self.collectionID = collectionID
        self.movies = movies
    }

    func load() async {
        state = .loading
        do {
            let collection = try await movies.collection(id: collectionID)
            let poster = collection.posterPath?.trimmingCharacters(in: .whitespacesAndNewlines)
            let posterPath = (poster?.isEmpty == false) ? poster : nil
            let overview = collection.overview.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = collection.parts
                .sorted(by: Self.undatedFirst)
                .map(CatalogMovieRow.init)
            if posterPath == nil, overview.isEmpty, parts.isEmpty {
                state = .empty
                return
            }
            let content = CollectionContent(
                id: collection.id,
                name: collection.name,
                overview: overview,
                posterPath: posterPath,
                parts: parts
            )
            state = .loaded(content)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    func retry() async {
        await load()
    }

    /// Missing release dates sort ahead of every dated part. Dated parts go oldest first.
    private static func undatedFirst(_ lhs: Movie, _ rhs: Movie) -> Bool {
        switch (lhs.releaseDate, rhs.releaseDate) {
        case (nil, nil):
            return lhs.id < rhs.id
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        case let (left?, right?) where left != right:
            return left < right
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
