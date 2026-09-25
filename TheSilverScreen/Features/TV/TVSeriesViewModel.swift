//
//  TVSeriesViewModel.swift
//  TheSilverScreen
//

import Foundation

struct TVSeriesContent: Sendable, Equatable {
    struct SeasonRow: Sendable, Equatable, Identifiable {
        let id: Int
        let name: String
        let seasonNumber: Int
        let episodeCountText: String
        let formattedAirDate: String
        let posterPath: String?
    }

    struct RecommendationRow: Sendable, Equatable, Identifiable {
        let id: Int
        let name: String
        let posterPath: String?
    }

    struct ReviewsSection: Sendable, Equatable {
        let items: [MovieReview]
        let nextPage: Int
        let hasMore: Bool
        let totalCount: Int
        let isLoadingPage: Bool
        let pageError: AppError?
    }

    let detail: TVSeriesDetail
    let formattedFirstAirDate: String
    let formattedLastAirDate: String
    let creatorsText: String
    let formattedRating: String
    let ratingAccessibilityLabel: String
    let seasons: [SeasonRow]
    let recommendations: [RecommendationRow]
    let reviews: ReviewsSection?
    var fullscreenImages: FullscreenImages?
}

/// Series detail reached from a person's credits or a recommendation.
@Observable
@MainActor
final class TVSeriesViewModel {
    private(set) var state: LoadState<TVSeriesContent> = .idle

    private let seriesID: Int
    private let shows: TVRepository

    init(seriesID: Int, shows: TVRepository) {
        self.seriesID = seriesID
        self.shows = shows
    }

    func load() async {
        state = .loading
        do {
            let detail = try await shows.series(id: seriesID)
            let reviews = await Self.loadReviews(seriesID: seriesID, shows: shows)
            state = .loaded(Self.makeContent(detail: detail, reviews: reviews))
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

    /// Pull to refresh. The series already on screen stays up if the request fails.
    func refresh() async {
        guard case .loaded(let current, _) = state else {
            await load()
            return
        }
        state = .loaded(current, activity: .refreshing)
        do {
            let detail = try await shows.series(id: seriesID)
            let reviews = await Self.loadReviews(seriesID: seriesID, shows: shows)
            state = .loaded(Self.makeContent(detail: detail, reviews: reviews))
        } catch is CancellationError {
            state = .loaded(current, activity: .none)
        } catch let error as AppError {
            state = .loaded(current, activity: .failed(error))
        } catch {
            state = .loaded(current, activity: .failed(.unknown))
        }
    }

    func openImages(initialID: String) {
        guard case .loaded(var content, let activity) = state, !content.detail.images.isEmpty else { return }
        content.fullscreenImages = FullscreenImages(
            initialID: initialID,
            images: content.detail.images,
            kind: .backdrop
        )
        state = .loaded(content, activity: activity)
    }

    func dismissImages() {
        guard case .loaded(var content, let activity) = state else { return }
        content.fullscreenImages = nil
        state = .loaded(content, activity: activity)
    }

    /// Opens the series poster. A missing path leaves the screen as it is.
    func openPoster() {
        guard case .loaded(var content, let activity) = state,
              let path = content.detail.posterPath,
              !path.isEmpty else { return }
        content.fullscreenImages = FullscreenImages(
            initialID: path,
            images: [MovieImage(filePath: path, voteAverage: 0)],
            kind: .poster
        )
        state = .loaded(content, activity: activity)
    }

    /// Next review page. Failures keep the reviews already on screen.
    func loadMoreReviews() async {
        guard case .loaded(let content, let activity) = state,
              let reviews = content.reviews,
              reviews.hasMore,
              !reviews.isLoadingPage else { return }

        state = .loaded(
            content.replacing(reviews: reviews.copy(isLoadingPage: true, pageError: nil)),
            activity: activity
        )

        do {
            let page = try await shows.reviews(seriesID: seriesID, page: reviews.nextPage)
            var seen = Set(reviews.items.map(\.id))
            var merged = reviews.items
            for review in page.reviews where seen.insert(review.id).inserted {
                merged.append(review)
            }
            guard case .loaded(let latest, let latestActivity) = state else { return }
            state = .loaded(
                latest.replacing(
                    reviews: TVSeriesContent.ReviewsSection(
                        items: merged,
                        nextPage: page.page + 1,
                        hasMore: page.hasMore,
                        totalCount: page.totalCount,
                        isLoadingPage: false,
                        pageError: nil
                    )
                ),
                activity: latestActivity
            )
        } catch is CancellationError {
            guard case .loaded(let latest, let latestActivity) = state,
                  let current = latest.reviews else { return }
            state = .loaded(
                latest.replacing(reviews: current.copy(isLoadingPage: false, pageError: nil)),
                activity: latestActivity
            )
        } catch let error as AppError {
            guard case .loaded(let latest, let latestActivity) = state,
                  let current = latest.reviews else { return }
            state = .loaded(
                latest.replacing(reviews: current.copy(isLoadingPage: false, pageError: error)),
                activity: latestActivity
            )
        } catch {
            guard case .loaded(let latest, let latestActivity) = state,
                  let current = latest.reviews else { return }
            state = .loaded(
                latest.replacing(reviews: current.copy(isLoadingPage: false, pageError: .unknown)),
                activity: latestActivity
            )
        }
    }

    private static func loadReviews(seriesID: Int, shows: TVRepository) async -> TVSeriesContent.ReviewsSection? {
        do {
            let page = try await shows.reviews(seriesID: seriesID, page: 1)
            guard !page.reviews.isEmpty else { return nil }
            return TVSeriesContent.ReviewsSection(
                items: page.reviews,
                nextPage: page.page + 1,
                hasMore: page.hasMore,
                totalCount: page.totalCount,
                isLoadingPage: false,
                pageError: nil
            )
        } catch is CancellationError {
            return nil
        } catch let error as AppError {
            return TVSeriesContent.ReviewsSection(
                items: [],
                nextPage: 1,
                hasMore: false,
                totalCount: 0,
                isLoadingPage: false,
                pageError: error
            )
        } catch {
            return TVSeriesContent.ReviewsSection(
                items: [],
                nextPage: 1,
                hasMore: false,
                totalCount: 0,
                isLoadingPage: false,
                pageError: .unknown
            )
        }
    }

    private static func makeContent(
        detail: TVSeriesDetail,
        reviews: TVSeriesContent.ReviewsSection?
    ) -> TVSeriesContent {
        let creators = detail.creators.isEmpty ? "Creator unknown" : detail.creators.joined(separator: ", ")
        let lastAirDate = detail.lastAirDate.map { "Last Air Date: \(DisplayDate.day($0))" } ?? "Last Air Date: Unknown"
        let seasons = detail.seasons.map { season in
            TVSeriesContent.SeasonRow(
                id: season.id,
                name: SeasonTitle.display(name: season.name, number: season.seasonNumber),
                seasonNumber: season.seasonNumber,
                episodeCountText: episodeCountText(season.episodeCount),
                formattedAirDate: DisplayDate.day(season.airDate),
                posterPath: season.posterPath
            )
        }
        let recommendations = detail.recommendations.map {
            TVSeriesContent.RecommendationRow(id: $0.id, name: $0.name, posterPath: $0.posterPath)
        }
        let reviewsSection = reviews
        return TVSeriesContent(
            detail: detail,
            formattedFirstAirDate: DisplayDate.day(detail.firstAirDate),
            formattedLastAirDate: lastAirDate,
            creatorsText: creators,
            formattedRating: TMDBRating.formatted(detail.voteAverage),
            ratingAccessibilityLabel: TMDBRating.accessibilityLabel(detail.voteAverage),
            seasons: seasons,
            recommendations: recommendations,
            reviews: reviewsSection,
            fullscreenImages: nil
        )
    }

    private static func episodeCountText(_ count: Int) -> String {
        count == 1 ? "1 episode" : "\(count) episodes"
    }
}

private extension TVSeriesContent {
    func replacing(reviews: ReviewsSection?) -> TVSeriesContent {
        TVSeriesContent(
            detail: detail,
            formattedFirstAirDate: formattedFirstAirDate,
            formattedLastAirDate: formattedLastAirDate,
            creatorsText: creatorsText,
            formattedRating: formattedRating,
            ratingAccessibilityLabel: ratingAccessibilityLabel,
            seasons: seasons,
            recommendations: recommendations,
            reviews: reviews,
            fullscreenImages: fullscreenImages
        )
    }
}

private extension TVSeriesContent.ReviewsSection {
    func copy(isLoadingPage: Bool, pageError: AppError?) -> Self {
        TVSeriesContent.ReviewsSection(
            items: items,
            nextPage: nextPage,
            hasMore: hasMore,
            totalCount: totalCount,
            isLoadingPage: isLoadingPage,
            pageError: pageError
        )
    }
}
