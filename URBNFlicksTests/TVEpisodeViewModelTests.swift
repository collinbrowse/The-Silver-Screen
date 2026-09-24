//
//  TVEpisodeViewModelTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class TVEpisodeViewModelTests: XCTestCase {

    func test_load_mapsHeaderCastGuestsAndCrew() async {
        let viewModel = TVEpisodeViewModel(
            seriesID: 1396,
            seasonNumber: 1,
            episodeNumber: 1,
            shows: TVRepository.test(client: FakeHTTPClient(stub: .success(TMDBFixtures.tvEpisodePilot)))
        )

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.title, "Pilot")
        XCTAssertEqual(content.episodeNumberText, "Episode 1")
        XCTAssertEqual(content.formattedAirDate, "Jan 20, 2008")
        XCTAssertEqual(content.overview, "The first cook.")
        XCTAssertEqual(content.stillPath, "/pilot.jpg")
        XCTAssertEqual(content.cast.map(\.role), ["Walter White"])
        XCTAssertEqual(content.guestStars.map(\.name), ["John Koyama"])
        XCTAssertEqual(content.directorsAndWriters.map(\.name), ["Vince Gilligan", "Story Person", "Screen Person"])
        XCTAssertFalse(content.directorsAndWriters.contains { $0.name == "Script Coordinator" })
        XCTAssertFalse(content.images.isEmpty)
        XCTAssertTrue(content.otherEpisodes.isEmpty)
    }

    func test_load_listsTheOtherEpisodesInTheSeason() async {
        let season = Data("""
        {
          "id": 1, "name": "Season 1", "season_number": 1,
          "episodes": [
            {"id": 10, "name": "Pilot", "episode_number": 1, "still_path": "/pilot.jpg"},
            {"id": 11, "name": "Cat's in the Bag...", "episode_number": 2, "still_path": "/e2.jpg"},
            {"id": 12, "name": "...And the Bag's in the River", "episode_number": 3}
          ]
        }
        """.utf8)
        let client = RoutingHTTPClient(routes: [
            "season/1/episode": .success(TMDBFixtures.tvEpisodePilot),
            "season/1": .success(season),
        ])
        let viewModel = TVEpisodeViewModel(
            seriesID: 1396,
            seasonNumber: 1,
            episodeNumber: 1,
            shows: TVRepository.test(client: client)
        )

        await viewModel.load()

        guard case .loaded(let content, _) = viewModel.state else {
            return XCTFail("Expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(content.otherEpisodes.map(\.title), ["Cat's in the Bag...", "...And the Bag's in the River"])
        XCTAssertEqual(content.otherEpisodes.map(\.episodeNumber), [2, 3])
    }
}
