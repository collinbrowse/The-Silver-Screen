//
//  Route.swift
//  URBNFlicks
//

import Foundation

/// Tabs on the bar. Older snapshots used Now Playing, Upcoming, and Top Movies;
/// those values decode as Browse so a restore does not fail.
enum AppTab: Hashable, Sendable {
    case browse
    case favorites
    case search
}

extension AppTab: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        switch raw {
        case "favorites":
            self = .favorites
        case "search":
            self = .search
        case "browse", "nowPlaying", "upcoming", "topMovies":
            self = .browse
        default:
            self = .browse
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .browse:
            try container.encode("browse")
        case .favorites:
            try container.encode("favorites")
        case .search:
            try container.encode("search")
        }
    }
}

enum Route: Hashable, Sendable, Codable {
    case movieDetail(id: Int)
    case person(id: Int)
    case personCredits(personID: Int, personName: String, department: CreditDepartment)
    case collection(id: Int)
    case tvSeries(id: Int)
    case tvSeason(seriesID: Int, seriesName: String, seasonNumber: Int)
    case tvEpisode(seriesID: Int, seriesName: String, seasonNumber: Int, episodeNumber: Int)
}
