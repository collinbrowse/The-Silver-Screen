//
//  MovieCatalogViewModel.swift
//  URBNFlicks
//
//  Paged movie lists that share one cell layout: Now Playing, Upcoming, and Popular.
//

import Foundation

/// Which TMDB movie list a catalog screen is showing.
enum MovieCatalogKind: Sendable, Equatable {
    case nowPlaying
    case upcoming
    case popular

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .upcoming: "Upcoming"
        case .popular: "Popular"
        }
    }
}

/// First page, refresh, and paging for a single movie catalog. Sort stays on Top Movies.
@Observable
@MainActor
final class MovieCatalogViewModel {
    private(set) var state: LoadState<[CatalogMovieRow]> = .idle
    /// Whether TMDB reported another page. The view stops asking once this is false.
    private(set) var hasMore = true

    let title: String

    private let kind: MovieCatalogKind
    private let movies: MovieRepository
    private var accumulated: [CatalogMovieRow] = []
    private var nextPage = 1
    private var isPaging = false

    init(kind: MovieCatalogKind, movies: MovieRepository) {
        self.kind = kind
        self.movies = movies
        self.title = kind.title
    }

    func load() async {
        state = .loading
        nextPage = 1
        hasMore = true
        accumulated = []

        do {
            let page = try await fetch(page: 1)
            applyFirstPage(page)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    func refresh() async {
        switch state {
        case .loaded(let current, _):
            state = .loaded(current, activity: .refreshing)
        case .failed, .empty, .idle:
            state = .loading
        case .loading:
            return
        }

        do {
            let page = try await fetch(page: 1)
            applyFirstPage(page)
        } catch is CancellationError {
            return
        } catch let error as AppError {
            if case .loaded(let current, _) = state {
                state = .loaded(current, activity: .failed(error))
            } else {
                state = .failed(error)
            }
        } catch {
            if case .loaded(let current, _) = state {
                state = .loaded(current, activity: .failed(.unknown))
            } else {
                state = .failed(.unknown)
            }
        }
    }

    /// Fetches the next page while keeping the current list on screen.
    /// Concurrent calls are ignored; failures stay on `.loaded` with a failed activity.
    func loadMore() async {
        guard hasMore, !isPaging else { return }
        guard case .loaded(let current, let activity) = state, activity == .none else { return }

        isPaging = true
        state = .loaded(current, activity: .loadingMore)
        defer { isPaging = false }

        do {
            let page = try await fetch(page: nextPage)
            let existingIDs = Set(accumulated.map(\.id))
            let unique = page.movies
                .map(CatalogMovieRow.init)
                .filter { !existingIDs.contains($0.id) }
            accumulated.append(contentsOf: unique)
            nextPage = page.page + 1
            hasMore = page.hasMore
            state = .loaded(accumulated)
        } catch is CancellationError {
            state = .loaded(accumulated)
        } catch let error as AppError {
            state = .loaded(accumulated, activity: .failed(error))
        } catch {
            state = .loaded(accumulated, activity: .failed(.unknown))
        }
    }

    func retry() async {
        await load()
    }

    private func fetch(page: Int) async throws -> MoviePage {
        switch kind {
        case .nowPlaying:
            return try await movies.nowPlaying(page: page)
        case .upcoming:
            return try await movies.upcoming(page: page)
        case .popular:
            return try await movies.popular(page: page)
        }
    }

    private func applyFirstPage(_ page: MoviePage) {
        accumulated = page.movies.map(CatalogMovieRow.init)
        nextPage = page.page + 1
        hasMore = page.hasMore
        state = accumulated.isEmpty ? .empty : .loaded(accumulated)
    }
}
