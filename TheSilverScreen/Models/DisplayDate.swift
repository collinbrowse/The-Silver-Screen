//
//  DisplayDate.swift
//  TheSilverScreen
//
//  Calendar-day text for list and detail metadata. FormatStyle follows the
//  device locale without a shared DateFormatter.
//

import Foundation

enum DisplayDate {
    /// A TMDB calendar day, formatted for `locale` without shifting the day into another timezone.
    static func day(_ date: Date?, locale: Locale = .current) -> String {
        guard let date else { return "Date unavailable" }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        guard let stable = utc.date(from: parts) else { return "Date unavailable" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: utc, timeZone: utc.timeZone)
            .year()
            .month(.abbreviated)
            .day()
        return stable.formatted(style)
    }
}
