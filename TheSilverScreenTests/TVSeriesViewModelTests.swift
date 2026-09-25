//
//  TVSeriesViewModelTests.swift
//  TheSilverScreenTests
//

import XCTest
@testable import TheSilverScreen

@MainActor
final class TVSeriesViewModelTests: XCTestCase {

    func test_load_formatsHeaderAndSortsSeasons() async {
        let client = RoutingHTTPClient(routes: [
            "/tv/1396/reviews": .success(TMDBFixtures.movieReviewsPage1),
            "/tv/1396": .success(TMDBFixtures.tvSeriesBreakingBad),
        ])
        let viewModel = TVSeriesViewModel(seriesID: 1396, shows: TVRepository.test(client: client))

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.detail.name, "Breaking Bad")
        XCTAssertEqual(content.formattedFirstAirDate, "Jan 20, 2008")
        XCTAssertEqual(content.formattedLastAirDate, "Last Air Date: Sep 29, 2013")
        XCTAssertEqual(content.creatorsText, "Vince Gilligan")
        XCTAssertEqual(content.formattedRating, "8.9 / 10")
        XCTAssertEqual(content.ratingAccessibilityLabel, "Rated 8.9 out of 10")
        XCTAssertEqual(content.seasons.map(\.seasonNumber), [1, 2])
        XCTAssertEqual(content.seasons.map(\.name), ["The Beginning", "Season 2"])
        XCTAssertEqual(content.seasons[0].episodeCountText, "7 episodes")
        XCTAssertEqual(content.recommendations.map(\.name), ["Better Call Saul"])
        XCTAssertEqual(content.reviews?.items.count, 1)
    }

    func test_loadMoreReviews_appendsNextPage() async {
        let client = SequencingHTTPClient(stubs: [
            .success(TMDBFixtures.tvSeriesBreakingBad),
            .success(TMDBFixtures.movieReviewsPage1),
            .success(TMDBFixtures.movieReviewsPage2),
        ])
        let viewModel = TVSeriesViewModel(seriesID: 1396, shows: TVRepository.test(client: client))
        await viewModel.load()

        await viewModel.loadMoreReviews()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.reviews?.items.map(\.id), ["rev-1", "rev-2"])
        XCTAssertEqual(content.reviews?.hasMore, false)
    }

    func test_loadMoreReviews_keepsTheListWhenTheNextPageFails() async {
        let client = SequencingHTTPClient(stubs: [
            .success(TMDBFixtures.tvSeriesBreakingBad),
            .success(TMDBFixtures.movieReviewsPage1),
            .failure(URLError(.notConnectedToInternet)),
        ])
        let viewModel = TVSeriesViewModel(seriesID: 1396, shows: TVRepository.test(client: client))
        await viewModel.load()

        await viewModel.loadMoreReviews()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.reviews?.items.map(\.id), ["rev-1"])
        XCTAssertEqual(content.reviews?.pageError, .offline)
    }

    func test_refresh_keepsTheSeriesWhenTheRequestFails() async {
        let client = SequencingHTTPClient(stubs: [
            .success(TMDBFixtures.tvSeriesBreakingBad),
            .success(TMDBFixtures.movieReviewsPage1),
            .failure(URLError(.notConnectedToInternet)),
        ])
        let viewModel = TVSeriesViewModel(seriesID: 1396, shows: TVRepository.test(client: client))
        await viewModel.load()

        await viewModel.refresh()

        guard case .loaded(let content, let activity) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.detail.name, "Breaking Bad")
        XCTAssertEqual(activity, .failed(.offline))
    }

    func test_load_usesUnknownCopyWhenCreatorAndLastAirDateAreMissing() async {
        let payload = Data("""
        {"id": 1, "name": "Untitled", "overview": "", "created_by": []}
        """.utf8)
        let client = SequencingHTTPClient(stubs: [
            .success(payload),
            .failure(URLError(.notConnectedToInternet)),
        ])
        let viewModel = TVSeriesViewModel(seriesID: 1, shows: TVRepository.test(client: client))

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.creatorsText, "Creator unknown")
        XCTAssertEqual(content.formattedLastAirDate, "Last Air Date: Unknown")
        XCTAssertEqual(content.formattedRating, "Unavailable")
        XCTAssertEqual(content.ratingAccessibilityLabel, "TMDB rating unavailable")
    }

    func test_openPoster_setsFullscreenPoster() async {
        let client = RoutingHTTPClient(routes: [
            "/tv/1396/reviews": .success(TMDBFixtures.movieReviewsPage1),
            "/tv/1396": .success(TMDBFixtures.tvSeriesBreakingBad),
        ])
        let viewModel = TVSeriesViewModel(seriesID: 1396, shows: TVRepository.test(client: client))
        await viewModel.load()

        viewModel.openPoster()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.fullscreenImages?.kind, .poster)
        XCTAssertEqual(content.fullscreenImages?.images.map(\.filePath), ["/bb.jpg"])
        XCTAssertEqual(content.fullscreenImages?.images.count, 1)
    }
}
