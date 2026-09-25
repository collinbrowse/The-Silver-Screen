//
//  TVSeasonViewModelTests.swift
//  TheSilverScreenTests
//

import XCTest
@testable import TheSilverScreen

@MainActor
final class TVSeasonViewModelTests: XCTestCase {

    func test_load_showsTheSeasonName() async {
        let viewModel = TVSeasonViewModel(
            seriesID: 1396,
            seriesName: "Breaking Bad",
            seasonNumber: 1,
            shows: TVRepository.test(client: FakeHTTPClient(stub: .success(TMDBFixtures.tvSeasonPilot)))
        )

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.seriesName, "Breaking Bad")
        XCTAssertEqual(content.displayName, "The Beginning")
        XCTAssertEqual(content.formattedAirDate, "Jan 20, 2008")
        XCTAssertEqual(content.formattedRating, "8.4 / 10")
        XCTAssertEqual(content.ratingAccessibilityLabel, "Rated 8.4 out of 10")
        XCTAssertEqual(content.overview, "Walter starts cooking.")
        XCTAssertEqual(content.episodes[0].directorLine, "Director: Vince Gilligan")
        XCTAssertEqual(content.cast[0].name, "Bryan Cranston")
    }

    func test_seasonTitle_usesTheNameWithoutANumberPrefix() {
        XCTAssertEqual(SeasonTitle.display(name: "Season 2", number: 2), "Season 2")
        XCTAssertEqual(SeasonTitle.display(name: "Specials", number: 0), "Specials")
        XCTAssertEqual(SeasonTitle.display(name: "The Beginning", number: 1), "The Beginning")
        XCTAssertEqual(SeasonTitle.display(name: "", number: 0), "Specials")
        XCTAssertEqual(SeasonTitle.display(name: "  ", number: 3), "Season 3")
    }

    func test_openPoster_setsFullscreenPoster() async {
        let viewModel = TVSeasonViewModel(
            seriesID: 1396,
            seriesName: "Breaking Bad",
            seasonNumber: 1,
            shows: TVRepository.test(client: FakeHTTPClient(stub: .success(TMDBFixtures.tvSeasonPilot)))
        )
        await viewModel.load()

        viewModel.openPoster()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.fullscreenImages?.kind, .poster)
        XCTAssertEqual(content.fullscreenImages?.images.map(\.filePath), ["/s1.jpg"])
        XCTAssertEqual(content.fullscreenImages?.images.count, 1)
    }
}
