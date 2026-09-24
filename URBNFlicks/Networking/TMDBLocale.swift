//
//  TMDBLocale.swift
//  URBNFlicks
//
//  Language and region query items from the device locale. Region is omitted
//  when the locale has none, so a language-only device does not send an empty region.
//

import Foundation

enum TMDBLocale {
    /// BCP-47 tag TMDB accepts, such as `en-US`. A locale with no region is just the language (`en`).
    static func languageTag(for locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        if let region = regionCode(for: locale) {
            return "\(language)-\(region)"
        }
        return language
    }

    /// ISO region, or nil when the device locale does not have one.
    static func regionCode(for locale: Locale) -> String? {
        guard let code = locale.region?.identifier, !code.isEmpty else { return nil }
        return code
    }

    static func queryItems(locale: Locale, page: Int, extra: [URLQueryItem] = []) -> [URLQueryItem] {
        var items = extra
        items.append(URLQueryItem(name: "language", value: languageTag(for: locale)))
        if let region = regionCode(for: locale) {
            items.append(URLQueryItem(name: "region", value: region))
        }
        items.append(URLQueryItem(name: "page", value: String(page)))
        return items
    }
}

/// UTC calendar-day strings for Discover date windows (`yyyy-MM-dd`).
enum TMDBDay {
    static let movieNowPlayingLookbackDays = 7
    static let tvOnAirSpanDays = 7

    static func string(from date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func adding(days: Int, to date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
