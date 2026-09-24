//
//  BrowseListViewModel.swift
//  URBNFlicks
//
//  One list for Movies, TV, and the mixed All feed. Changing media, window,
//  or sort drops the pages on screen. A response whose generation does not
//  match that selection is ignored, including a page that arrives after refresh.
//

import Foundation

@Observable
@MainActor
final class BrowseListViewModel {
    private(set) var media: BrowseMedia = .movies
    private(set) var window: BrowseWindow = .all
    private(set) var sort: BrowseSort = .popular
    private(set) var state: LoadState<[BrowseRow]> = .idle
    /// Whether another page can still extend the list on screen.
    private(set) var hasMore = true

    /// Changes when the three controls change, so the view can jump back to the top.
    private(set) var selectionToken = 0

    private let movies: MovieRepository
    private let shows: TVRepository
    private let locale: Locale
    private let today: @Sendable () -> Date

    private var generation = 0
    private var merge = BrowseMerge()
    private var moviePage = 1
    private var showPage = 1
    private var movieHasMore = true
    private var showHasMore = true
    private var activePagingTicket: Int?
    private var pagingTicket = 0
    private var pagingTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?

    init(
        movies: MovieRepository,
        shows: TVRepository,
        locale: Locale = .current,
        today: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.movies = movies
        self.shows = shows
        self.locale = locale
        self.today = today
    }

    func load() async {
        guard case .idle = state else { return }
        await reload(keepVisible: false)
    }

    func retry() async {
        await reload(keepVisible: false)
    }

    /// Pull to refresh. The rows stay up until the new first page arrives.
    func refresh() async {
        await reload(keepVisible: true)
    }

    /// Each segment opens on that tab's popular list, the same lists Search shows before a query.
    func setMedia(_ media: BrowseMedia) async {
        guard media != self.media else { return }
        self.media = media
        window = .all
        sort = .popular
        selectionToken += 1
        await reload(keepVisible: false)
    }

    func setWindow(_ window: BrowseWindow) async {
        guard window != self.window else { return }
        self.window = window
        selectionToken += 1
        await reload(keepVisible: false)
    }

    func setSort(_ sort: BrowseSort) async {
        guard sort != self.sort else { return }
        self.sort = sort
        selectionToken += 1
        await reload(keepVisible: false)
    }

    /// Fetches the next page while keeping the current list on screen.
    /// A second call while one is in flight does nothing. A page that belongs
    /// to an older selection or an older refresh is discarded.
    func loadMore() async {
        guard hasMore, activePagingTicket == nil else { return }
        guard case .loaded(_, let activity) = state, activity == .none else { return }

        pagingTicket += 1
        let ticket = pagingTicket
        let token = generation
        activePagingTicket = ticket
        let task = Task { @MainActor in
            await self.fetchMore(token: token)
        }
        pagingTask = task
        await task.value
        if activePagingTicket == ticket {
            activePagingTicket = nil
            pagingTask = nil
        }
    }

    private func reload(keepVisible: Bool) async {
        cancelPaging()
        reloadTask?.cancel()
        generation += 1
        let token = generation
        let task = Task { @MainActor in
            await self.performReload(token: token, keepVisible: keepVisible)
        }
        reloadTask = task
        await task.value
    }

    private func performReload(token: Int, keepVisible: Bool) async {
        if Task.isCancelled || token != generation { return }

        let visible = loadedRows
        if keepVisible, let visible {
            state = .loaded(visible, activity: .refreshing)
        } else {
            resetBuffers()
            state = .loading
        }

        do {
            let fresh = try await fetchFirstPages()
            guard token == generation, !Task.isCancelled else { return }
            resetBuffers()
            apply(fresh)
            publish(activity: .none)
        } catch is CancellationError {
            return
        } catch {
            guard token == generation else { return }
            let appError = (error as? AppError) ?? .unknown
            if keepVisible, let visible {
                state = .loaded(visible, activity: .failed(appError))
            } else {
                state = .failed(appError)
            }
        }
    }

    private func fetchMore(token: Int) async {
        guard case .loaded(let current, _) = state else { return }
        state = .loaded(current, activity: .loadingMore)
        do {
            try await fetchNextPages()
            guard token == generation, !Task.isCancelled else { return }
            publish(activity: .none)
        } catch is CancellationError {
            guard token == generation else { return }
            if case .loaded(let rows, _) = state {
                state = .loaded(rows, activity: .none)
            }
        } catch {
            guard token == generation else { return }
            let appError = (error as? AppError) ?? .unknown
            let rows = loadedRows ?? current
            state = .loaded(rows, activity: .failed(appError))
        }
    }

    private struct FreshPages {
        var movies: MoviePage?
        var shows: TVSeriesPage?
    }

    private func fetchFirstPages() async throws -> FreshPages {
        switch media {
        case .movies:
            return FreshPages(movies: try await movieList(page: 1), shows: nil)
        case .tv:
            return FreshPages(movies: nil, shows: try await showList(page: 1))
        case .all:
            async let movieRequest = movieList(page: 1)
            async let showRequest = showList(page: 1)
            return try await FreshPages(movies: movieRequest, shows: showRequest)
        }
    }

    private func fetchNextPages() async throws {
        switch media {
        case .movies:
            guard movieHasMore else { return }
            let page = try await movieList(page: moviePage)
            guard !Task.isCancelled else { throw CancellationError() }
            merge.appendMovies(page.movies.map(BrowseCandidate.movie))
            moviePage = page.page + 1
            movieHasMore = page.hasMore
        case .tv:
            guard showHasMore else { return }
            let page = try await showList(page: showPage)
            guard !Task.isCancelled else { throw CancellationError() }
            merge.appendShows(page.series.map(BrowseCandidate.series))
            showPage = page.page + 1
            showHasMore = page.hasMore
        case .all:
            let fetchMovies = merge.needsMoviePage && movieHasMore
            let fetchShows = merge.needsShowPage && showHasMore
            if fetchMovies && fetchShows {
                async let movieRequest = movieList(page: moviePage)
                async let showRequest = showList(page: showPage)
                let (movieResult, showResult) = try await (movieRequest, showRequest)
                guard !Task.isCancelled else { throw CancellationError() }
                merge.appendMovies(movieResult.movies.map(BrowseCandidate.movie))
                moviePage = movieResult.page + 1
                movieHasMore = movieResult.hasMore
                merge.appendShows(showResult.series.map(BrowseCandidate.series))
                showPage = showResult.page + 1
                showHasMore = showResult.hasMore
            } else if fetchMovies {
                let page = try await movieList(page: moviePage)
                guard !Task.isCancelled else { throw CancellationError() }
                merge.appendMovies(page.movies.map(BrowseCandidate.movie))
                moviePage = page.page + 1
                movieHasMore = page.hasMore
            } else if fetchShows {
                let page = try await showList(page: showPage)
                guard !Task.isCancelled else { throw CancellationError() }
                merge.appendShows(page.series.map(BrowseCandidate.series))
                showPage = page.page + 1
                showHasMore = page.hasMore
            }
            merge.consume(sort: sort, moviesHaveMore: movieHasMore, showsHaveMore: showHasMore)
        }
    }

    /// Popular with the All window is the Search landing list. Other filters stay on Discover.
    private var usesPopularList: Bool {
        sort == .popular && window == .all
    }

    private func movieList(page: Int) async throws -> MoviePage {
        if usesPopularList {
            return try await movies.popular(page: page, locale: locale)
        }
        return try await movies.discover(
            sort: sort,
            window: window,
            page: page,
            locale: locale,
            today: today()
        )
    }

    private func showList(page: Int) async throws -> TVSeriesPage {
        if usesPopularList {
            return try await shows.popular(page: page, locale: locale)
        }
        return try await shows.discover(
            sort: sort,
            window: window,
            page: page,
            locale: locale,
            today: today()
        )
    }

    private func apply(_ fresh: FreshPages) {
        if let movies = fresh.movies {
            merge.appendMovies(movies.movies.map(BrowseCandidate.movie))
            moviePage = movies.page + 1
            movieHasMore = movies.hasMore
        } else {
            movieHasMore = false
        }
        if let shows = fresh.shows {
            merge.appendShows(shows.series.map(BrowseCandidate.series))
            showPage = shows.page + 1
            showHasMore = shows.hasMore
        } else {
            showHasMore = false
        }
        if media == .all {
            merge.consume(sort: sort, moviesHaveMore: movieHasMore, showsHaveMore: showHasMore)
        }
    }

    private func publish(activity: LoadActivity) {
        let rows = currentCandidates.map { BrowseRow(candidate: $0, locale: locale) }
        switch media {
        case .movies:
            hasMore = movieHasMore
        case .tv:
            hasMore = showHasMore
        case .all:
            let moviesOpen = merge.movieCursor < merge.movies.count || movieHasMore
            let showsOpen = merge.showCursor < merge.shows.count || showHasMore
            hasMore = moviesOpen || showsOpen
        }
        if rows.isEmpty {
            state = activity == .none ? .empty : .loaded(rows, activity: activity)
            hasMore = false
        } else {
            state = .loaded(rows, activity: activity)
        }
    }

    private var currentCandidates: [BrowseCandidate] {
        switch media {
        case .movies: merge.movies
        case .tv: merge.shows
        case .all: merge.shown
        }
    }

    private var loadedRows: [BrowseRow]? {
        if case .loaded(let rows, _) = state { return rows }
        return nil
    }

    private func resetBuffers() {
        merge.reset()
        moviePage = 1
        showPage = 1
        movieHasMore = true
        showHasMore = true
    }

    private func cancelPaging() {
        pagingTask?.cancel()
        pagingTask = nil
        activePagingTicket = nil
    }
}
