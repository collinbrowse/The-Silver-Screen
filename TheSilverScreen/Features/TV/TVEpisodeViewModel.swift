//
//  TVEpisodeViewModel.swift
//  TheSilverScreen
//

import Foundation

struct TVEpisodeContent: Sendable, Equatable {
    let title: String
    let episodeNumberText: String
    let overview: String
    let formattedAirDate: String
    let formattedRating: String
    let ratingAccessibilityLabel: String
    let stillPath: String?
    let images: [MovieImage]
    let cast: [TVCredit]
    let guestStars: [TVCredit]
    let directorsAndWriters: [TVCredit]
    /// The rest of this season, in episode order. The episode on screen is left out.
    let otherEpisodes: [TVEpisodeSummary]
    var fullscreenImages: FullscreenImages?
}

/// One episode, opened from the episode list on a season.
@Observable
@MainActor
final class TVEpisodeViewModel {
    private(set) var state: LoadState<TVEpisodeContent> = .idle

    private let seriesID: Int
    private let seasonNumber: Int
    private let episodeNumber: Int
    private let shows: TVRepository

    init(seriesID: Int, seasonNumber: Int, episodeNumber: Int, shows: TVRepository) {
        self.seriesID = seriesID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.shows = shows
    }

    func load() async {
        state = .loading
        do {
            async let episodeCall = shows.episode(
                seriesID: seriesID,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            async let othersCall = otherEpisodes()
            let episode = try await episodeCall
            let others = try await othersCall
            state = .loaded(Self.makeContent(episode, otherEpisodes: others))
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

    /// Season list is extra. A failure here leaves the episode on screen with no carousel.
    private func otherEpisodes() async throws -> [TVEpisodeSummary] {
        do {
            let season = try await shows.season(seriesID: seriesID, seasonNumber: seasonNumber)
            return season.episodes.filter { $0.episodeNumber != episodeNumber }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return []
        }
    }

    private static func makeContent(
        _ episode: TVEpisodeDetail,
        otherEpisodes: [TVEpisodeSummary]
    ) -> TVEpisodeContent {
        TVEpisodeContent(
            title: episode.title,
            episodeNumberText: "Episode \(episode.episodeNumber)",
            overview: episode.overview,
            formattedAirDate: DisplayDate.day(episode.airDate),
            formattedRating: TMDBRating.formatted(episode.voteAverage),
            ratingAccessibilityLabel: TMDBRating.accessibilityLabel(episode.voteAverage),
            stillPath: episode.stillPath,
            images: episode.images,
            cast: episode.cast,
            guestStars: episode.guestStars,
            directorsAndWriters: episode.directorsAndWriters,
            otherEpisodes: otherEpisodes,
            fullscreenImages: nil
        )
    }
}
