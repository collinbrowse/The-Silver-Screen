//
//  MovieDetailViewModel.swift
//  URBNFlicks
//

import Foundation

struct MovieDetailContent: Sendable, Equatable {
    let detail: MovieDetail
    let isFavorite: Bool
    let formattedRating: String
    let ratingAccessibilityLabel: String
    let formattedBudget: String
    let budgetAccessibilityLabel: String
    let formattedRevenue: String
    let revenueAccessibilityLabel: String
    let formattedReleaseDate: String
}

@Observable
@MainActor
final class MovieDetailViewModel {
    private(set) var state: LoadState<MovieDetailContent> = .idle

    private let movieID: Int
    private let movies: MovieRepository
    private let favorites: FavoritesRepository

    init(movieID: Int, movies: MovieRepository, favorites: FavoritesRepository) {
        self.movieID = movieID
        self.movies = movies
        self.favorites = favorites
    }

    func load() async {
        state = .loading

        do {
            let detail = try await movies.movieDetail(id: movieID)
            let isFavorite = (try? await favorites.isFavorite(id: movieID)) ?? false
            state = .loaded(Self.makeContent(detail: detail, isFavorite: isFavorite))
        } catch is CancellationError {
            return
        } catch let error as AppError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }

    func retry() async {
        await load()
    }

    func toggleFavorite() async {
        guard case .loaded(let content, _) = state else { return }

        do {
            let isFavorite = try await favorites.toggle(movie: content.detail.asMovie())
            state = .loaded(
                Self.makeContent(detail: content.detail, isFavorite: isFavorite),
                activity: .none
            )
        } catch is CancellationError {
            return
        } catch let error as AppError {
            state = .loaded(content, activity: .failed(error))
        } catch {
            state = .loaded(content, activity: .failed(.unknown))
        }
    }

    // MARK: - Formatting

    static func makeContent(detail: MovieDetail, isFavorite: Bool) -> MovieDetailContent {
        let budget = formatCurrency(detail.budget)
        let revenue = formatCurrency(detail.revenue)
        return MovieDetailContent(
            detail: detail,
            isFavorite: isFavorite,
            formattedRating: formatRating(detail.voteAverage),
            ratingAccessibilityLabel: ratingAccessibility(detail.voteAverage),
            formattedBudget: budget.display,
            budgetAccessibilityLabel: budget.accessibility,
            formattedRevenue: revenue.display,
            revenueAccessibilityLabel: revenue.accessibility,
            formattedReleaseDate: formatReleaseDate(detail.releaseDate)
        )
    }

    static func formatRating(_ value: Double) -> String {
        String(format: "%.1f / 10", value)
    }

    static func ratingAccessibility(_ value: Double) -> String {
        String(format: "Rated %.1f out of 10", value)
    }

    static func formatReleaseDate(_ date: Date?) -> String {
        guard let date else { return "Not available" }
        return displayDateFormatter.string(from: date)
    }

    static func formatCurrency(_ amount: Int) -> (display: String, accessibility: String) {
        guard amount > 0 else {
            return ("Not available", "Not available")
        }

        let accessibility: String
        if let full = fullCurrencyFormatter.string(from: NSNumber(value: amount)) {
            accessibility = full
        } else {
            accessibility = "$\(amount)"
        }

        if amount >= 1_000_000 {
            let millions = Double(amount) / 1_000_000
            return (String(format: "$%.1fM", millions), accessibility)
        }
        if amount >= 1_000 {
            let thousands = Double(amount) / 1_000
            return (String(format: "$%.1fK", thousands), accessibility)
        }
        return (accessibility, accessibility)
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let fullCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
