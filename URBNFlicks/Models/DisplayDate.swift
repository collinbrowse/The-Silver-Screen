//
//  DisplayDate.swift
//  URBNFlicks
//
//  Calendar-day text for list and detail metadata. FormatStyle follows the
//  device locale without a shared DateFormatter.
//

import Foundation

enum DisplayDate {
    /// "Jan 12, 2024" in `en_US`, or "Date unavailable" when TMDB omitted the day.
    /// Month, day, and year follow the device locale.
    static func day(_ date: Date?, locale: Locale = .current) -> String {
        guard let date else { return "Date unavailable" }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let style = Date.FormatStyle(
            date: .abbreviated,
            time: .omitted,
            locale: locale,
            calendar: utc,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        .year()
        .month(.abbreviated)
        .day()
        return date.formatted(style)
    }
}
