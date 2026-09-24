//
//  CatalogMedia.swift
//  URBNFlicks
//
//  Display rows for browsable movie, TV, and people lists. Genre names and
//  dates are resolved here so list views only render strings.
//

import Foundation

struct CatalogMovieRow: Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let posterPath: String?
    let genreNames: [String]
    let formattedReleaseDate: String
    let genreIDs: [Int]
    let releaseDate: Date?
    let voteAverage: Double

    init(movie: Movie) {
        id = movie.id
        title = movie.title
        posterPath = movie.posterPath
        genreIDs = movie.genreIDs
        genreNames = MovieGenreCatalog.names(for: movie.genreIDs)
        releaseDate = movie.releaseDate
        voteAverage = movie.voteAverage
        formattedReleaseDate = DisplayDate.day(movie.releaseDate)
    }

    func asMovie() -> Movie {
        Movie(
            id: id,
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            genreIDs: genreIDs
        )
    }
}

struct CatalogTVRow: Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
    let genreNames: [String]
    let formattedFirstAirDate: String
    let genreIDs: [Int]
    let firstAirDate: Date?

    init(series: TVSeriesSummary) {
        id = series.id
        name = series.name
        posterPath = series.posterPath
        genreIDs = series.genreIDs
        genreNames = TVGenreCatalog.names(for: series.genreIDs)
        firstAirDate = series.firstAirDate
        formattedFirstAirDate = DisplayDate.day(series.firstAirDate)
    }

    func asSeries() -> FavoriteTVSeries {
        FavoriteTVSeries(
            id: id,
            name: name,
            posterPath: posterPath,
            releaseDate: firstAirDate,
            genreIDs: genreIDs
        )
    }
}

/// A person as they appear in popular and search lists — not a full biography.
struct PersonSummary: Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?
}

struct PersonPage: Sendable, Equatable {
    let people: [PersonSummary]
    let page: Int
    let hasMore: Bool
}

struct CatalogPersonRow: Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?

    init(person: PersonSummary) {
        id = person.id
        name = person.name
        profilePath = person.profilePath
        let department = person.knownForDepartment?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        knownForDepartment = (department?.isEmpty == false) ? department : nil
    }

    func asPerson() -> FavoritePerson {
        FavoritePerson(
            id: id,
            name: name,
            profilePath: profilePath,
            knownForDepartment: knownForDepartment
        )
    }
}
