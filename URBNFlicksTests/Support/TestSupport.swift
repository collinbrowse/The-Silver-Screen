//
//  TestSupport.swift
//  URBNFlicksTests
//

import Foundation
@testable import URBNFlicks

struct SilentLogger: AppLogging {
    func debug(_ message: String, category: LogCategory) {}
    func error(_ message: String, category: LogCategory) {}
}

enum TestMovies {
    static func make(
        id: Int = 1,
        title: String = "Short Movie Title",
        posterPath: String? = nil,
        releaseDate: Date? = nil,
        voteAverage: Double = 8.0,
        genreIDs: [Int] = []
    ) -> Movie {
        Movie(
            id: id,
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            genreIDs: genreIDs
        )
    }

    static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }
}
