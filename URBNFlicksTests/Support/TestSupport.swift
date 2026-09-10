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

extension MovieRepository {
    /// Test factory: real repository over a fake client, no retry backoff delay.
    static func test(
        client: any HTTPClient,
        apiKey: String = "test",
        logger: any AppLogging = SilentLogger()
    ) -> MovieRepository {
        MovieRepository(
            client: client,
            apiKey: apiKey,
            logger: logger,
            sleeper: NoopSleeper()
        )
    }
}

extension PersonRepository {
    /// Test factory: real repository over a fake client, no retry backoff delay.
    static func test(
        client: any HTTPClient,
        apiKey: String = "test",
        logger: any AppLogging = SilentLogger()
    ) -> PersonRepository {
        PersonRepository(
            client: client,
            apiKey: apiKey,
            logger: logger,
            sleeper: NoopSleeper()
        )
    }
}

extension ImageLoader {
    static func test(
        client: any HTTPClient,
        logger: any AppLogging = SilentLogger()
    ) -> ImageLoader {
        ImageLoader(client: client, logger: logger, sleeper: NoopSleeper())
    }
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
