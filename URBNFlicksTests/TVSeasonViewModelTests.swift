//
//  TVSeasonViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class TVSeasonViewModelTests: XCTestCase {

    func test_load_prefixesSeasonNumber() async {
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
        XCTAssertEqual(content.displayName, "1 · The Beginning")
        XCTAssertEqual(content.formattedAirDate, "Jan 20, 2008")
        XCTAssertEqual(content.overview, "Walter starts cooking.")
        XCTAssertEqual(content.episodes[0].directorLine, "Director: Vince Gilligan")
        XCTAssertEqual(content.cast[0].name, "Bryan Cranston")
    }

    func test_seasonTitle_alwaysLeadsWithTheNumber() {
        XCTAssertEqual(SeasonTitle.display(name: "Season 2", number: 2), "2 · Season 2")
        XCTAssertEqual(SeasonTitle.display(name: "Specials", number: 0), "0 · Specials")
    }
}
