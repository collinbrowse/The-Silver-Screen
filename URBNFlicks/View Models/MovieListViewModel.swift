//
//  MovieListViewModel.swift
//  URBNFlicks
//
//  Created by URBN
//

import Foundation

@Observable
@MainActor
final class MovieListViewModel {
    private(set) var state: LoadState<[Movie]> = .idle

    private let movies: MovieRepository
    private var accumulated: [Movie] = []
    private var nextPage = 1
    private var hasMore = true
    private var isPaging = false

    init(movies: MovieRepository) {
        self.movies = movies
    }

    func load() async {
        state = .loading
        nextPage = 1
        hasMore = true
        accumulated = []

        do {
            let page = try await movies.topMovies(page: 1)
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
            let page = try await movies.topMovies(page: 1)
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

    func loadMore() async {
        guard hasMore, !isPaging else { return }
        guard case .loaded(let current, let activity) = state, activity == .none else { return }

        isPaging = true
        state = .loaded(current, activity: .loadingMore)
        defer { isPaging = false }

        do {
            let page = try await movies.topMovies(page: nextPage)
            let existingIDs = Set(accumulated.map(\.id))
            let unique = page.movies.filter { !existingIDs.contains($0.id) }
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

    private func applyFirstPage(_ page: MoviePage) {
        accumulated = page.movies
        nextPage = page.page + 1
        hasMore = page.hasMore

        if accumulated.isEmpty {
            state = .empty
        } else {
            state = .loaded(accumulated)
        }
    }
}
