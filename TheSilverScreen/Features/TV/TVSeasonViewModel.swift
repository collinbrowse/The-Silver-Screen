//
//  TVSeasonViewModel.swift
//  TheSilverScreen
//

import Foundation

struct TVSeasonContent: Sendable, Equatable {
    let seriesName: String
    let displayName: String
    let overview: String
    let formattedAirDate: String
    let formattedRating: String
    let ratingAccessibilityLabel: String
    let posterPath: String?
    let images: [MovieImage]
    let cast: [TVCredit]
    let directorsAndWriters: [TVCredit]
    let episodes: [TVEpisodeSummary]
    var fullscreenImages: FullscreenImages?
}

/// One season, opened from the seasons carousel on a series.
@Observable
@MainActor
final class TVSeasonViewModel {
    private(set) var state: LoadState<TVSeasonContent> = .idle

    private let seriesID: Int
    private let seriesName: String
    private let seasonNumber: Int
    private let shows: TVRepository

    init(seriesID: Int, seriesName: String, seasonNumber: Int, shows: TVRepository) {
        self.seriesID = seriesID
        self.seriesName = seriesName
        self.seasonNumber = seasonNumber
        self.shows = shows
    }

    func load() async {
        state = .loading
        do {
            let season = try await shows.season(seriesID: seriesID, seasonNumber: seasonNumber)
            state = .loaded(Self.makeContent(season: season, seriesName: seriesName))
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

    func openImages(initialID: String) {
        guard case .loaded(var content, let activity) = state, !content.images.isEmpty else { return }
        content.fullscreenImages = FullscreenImages(
            initialID: initialID,
            images: content.images,
            kind: .backdrop
        )
        state = .loaded(content, activity: activity)
    }

    func dismissImages() {
        guard case .loaded(var content, let activity) = state else { return }
        content.fullscreenImages = nil
        state = .loaded(content, activity: activity)
    }

    /// Opens the season poster. A missing path leaves the screen as it is.
    func openPoster() {
        guard case .loaded(var content, let activity) = state,
              let path = content.posterPath,
              !path.isEmpty else { return }
        content.fullscreenImages = FullscreenImages(
            initialID: path,
            images: [MovieImage(filePath: path, voteAverage: 0)],
            kind: .poster
        )
        state = .loaded(content, activity: activity)
    }

    private static func makeContent(season: TVSeasonDetail, seriesName: String) -> TVSeasonContent {
        TVSeasonContent(
            seriesName: seriesName,
            displayName: SeasonTitle.display(name: season.name, number: season.seasonNumber),
            overview: season.overview,
            formattedAirDate: DisplayDate.day(season.airDate),
            formattedRating: TMDBRating.formatted(season.voteAverage),
            ratingAccessibilityLabel: TMDBRating.accessibilityLabel(season.voteAverage),
            posterPath: season.posterPath,
            images: season.images,
            cast: season.cast,
            directorsAndWriters: season.directorsAndWriters,
            episodes: season.episodes,
            fullscreenImages: nil
        )
    }
}
