//
//  MovieDetailViewModel.swift
//  URBNFlicks
//

import Foundation

struct MovieDetailContent: Sendable, Equatable {
    struct ImagesSection: Sendable, Equatable {
        let items: [MovieImage]
    }

    struct CastSection: Sendable, Equatable {
        let members: [CastMember]
    }

    struct CrewSection: Sendable, Equatable {
        let people: [CreditedPerson]
    }

    struct SimilarSection: Sendable, Equatable {
        struct Item: Sendable, Equatable, Identifiable {
            let movie: Movie
            let genreNames: [String]
            let formattedReleaseDate: String

            var id: Int { movie.id }
        }

        let items: [Item]
    }

    struct CollectionSection: Sendable, Equatable {
        let title: String
        let movies: [Movie]
    }

    struct ReviewsSection: Sendable, Equatable {
        let items: [MovieReview]
        let nextPage: Int
        let hasMore: Bool
        let isLoadingPage: Bool
        let pageError: AppError?
    }

    let detail: MovieDetail
    let isFavorite: Bool
    let formattedRating: String
    let ratingAccessibilityLabel: String
    let formattedBudget: String
    let budgetAccessibilityLabel: String
    let formattedRevenue: String
    let revenueAccessibilityLabel: String
    let formattedReleaseDate: String
    let images: ImagesSection?
    let cast: CastSection?
    let crew: CrewSection?
    let similar: SimilarSection?
    let collection: CollectionSection?
    let reviews: ReviewsSection?

    /// Non-nil while the image lightbox is open (presentation state owned by the VM so
    /// UIKit-hosted detail can present reliably).
    var fullscreenImages: FullscreenImages?
}

struct FullscreenImages: Sendable, Equatable, Identifiable {
    var id: String { initialID }
    let initialID: String
    let images: [MovieImage]
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
            async let collectionSection = Self.loadCollectionSection(
                movieID: movieID,
                detail: detail,
                movies: movies
            )
            async let reviewsSection = Self.loadReviewsSection(
                movieID: movieID,
                movies: movies
            )
            let content = Self.makeContent(
                detail: detail,
                isFavorite: isFavorite,
                collection: await collectionSection,
                reviews: await reviewsSection
            )
            state = .loaded(content)
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
                content.replacing(isFavorite: isFavorite),
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

    func loadMoreReviews() async {
        guard case .loaded(let content, let activity) = state,
              let reviews = content.reviews,
              reviews.hasMore,
              !reviews.isLoadingPage else { return }

        state = .loaded(
            content.replacing(
                reviews: ReviewsPatch(
                    items: reviews.items,
                    nextPage: reviews.nextPage,
                    hasMore: reviews.hasMore,
                    isLoadingPage: true,
                    pageError: nil
                )
            ),
            activity: activity
        )

        do {
            let page = try await movies.movieReviews(id: movieID, page: reviews.nextPage)
            var seen = Set(reviews.items.map(\.id))
            var merged = reviews.items
            for review in page.reviews where seen.insert(review.id).inserted {
                merged.append(review)
            }
            guard case .loaded(let latest, let latestActivity) = state else { return }
            state = .loaded(
                latest.replacing(
                    reviews: ReviewsPatch(
                        items: merged,
                        nextPage: page.page + 1,
                        hasMore: page.hasMore,
                        isLoadingPage: false,
                        pageError: nil
                    )
                ),
                activity: latestActivity
            )
        } catch is CancellationError {
            return
        } catch let error as AppError {
            guard case .loaded(let latest, let latestActivity) = state,
                  let current = latest.reviews else { return }
            state = .loaded(
                latest.replacing(
                    reviews: ReviewsPatch(
                        items: current.items,
                        nextPage: current.nextPage,
                        hasMore: current.hasMore,
                        isLoadingPage: false,
                        pageError: error
                    )
                ),
                activity: latestActivity
            )
        } catch {
            guard case .loaded(let latest, let latestActivity) = state,
                  let current = latest.reviews else { return }
            state = .loaded(
                latest.replacing(
                    reviews: ReviewsPatch(
                        items: current.items,
                        nextPage: current.nextPage,
                        hasMore: current.hasMore,
                        isLoadingPage: false,
                        pageError: .unknown
                    )
                ),
                activity: latestActivity
            )
        }
    }

    // MARK: - Formatting

    static func makeContent(
        detail: MovieDetail,
        isFavorite: Bool,
        collection: MovieDetailContent.CollectionSection? = nil,
        reviews: MovieDetailContent.ReviewsSection? = nil
    ) -> MovieDetailContent {
        let budget = formatCurrency(detail.budget)
        let revenue = formatCurrency(detail.revenue)
        let images = detail.images.isEmpty
            ? nil
            : MovieDetailContent.ImagesSection(items: detail.images)
        let cast = detail.cast.isEmpty
            ? nil
            : MovieDetailContent.CastSection(members: detail.cast)
        let crewPeople = MovieRepository.creditedDirectorsAndWriters(from: detail.crew)
        let crew = crewPeople.isEmpty
            ? nil
            : MovieDetailContent.CrewSection(people: crewPeople)
        let similarItems = detail.similar.map { movie in
            MovieDetailContent.SimilarSection.Item(
                movie: movie,
                genreNames: MovieGenreCatalog.names(for: movie.genreIDs),
                formattedReleaseDate: formatReleaseDate(movie.releaseDate)
            )
        }
        let similar = similarItems.isEmpty
            ? nil
            : MovieDetailContent.SimilarSection(items: similarItems)

        return MovieDetailContent(
            detail: detail,
            isFavorite: isFavorite,
            formattedRating: formatRating(detail.voteAverage),
            ratingAccessibilityLabel: ratingAccessibility(detail.voteAverage),
            formattedBudget: budget.display,
            budgetAccessibilityLabel: budget.accessibility,
            formattedRevenue: revenue.display,
            revenueAccessibilityLabel: revenue.accessibility,
            formattedReleaseDate: formatReleaseDate(detail.releaseDate),
            images: images,
            cast: cast,
            crew: crew,
            similar: similar,
            collection: collection,
            reviews: reviews,
            fullscreenImages: nil
        )
    }

    func openImages(initialID: String) {
        guard case .loaded(let content, let activity) = state,
              let images = content.images else { return }
        state = .loaded(
            content.withFullscreen(
                FullscreenImages(initialID: initialID, images: images.items)
            ),
            activity: activity
        )
    }

    func dismissImages() {
        guard case .loaded(let content, let activity) = state else { return }
        state = .loaded(content.withFullscreen(nil), activity: activity)
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

    static func formatReviewDate(_ date: Date?) -> String {
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

    // MARK: - Private

    private static func loadCollectionSection(
        movieID: Int,
        detail: MovieDetail,
        movies: MovieRepository
    ) async -> MovieDetailContent.CollectionSection? {
        guard let ref = detail.collection else { return nil }
        do {
            let collection = try await movies.collection(id: ref.id)
            let others = collection.parts.filter { $0.id != movieID }
            guard !others.isEmpty else { return nil }
            return MovieDetailContent.CollectionSection(title: ref.name, movies: others)
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private static func loadReviewsSection(
        movieID: Int,
        movies: MovieRepository
    ) async -> MovieDetailContent.ReviewsSection? {
        do {
            let page = try await movies.movieReviews(id: movieID, page: 1)
            guard !page.reviews.isEmpty else { return nil }
            return MovieDetailContent.ReviewsSection(
                items: page.reviews,
                nextPage: page.page + 1,
                hasMore: page.hasMore,
                isLoadingPage: false,
                pageError: nil
            )
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
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

private struct ReviewsPatch {
    let items: [MovieReview]
    let nextPage: Int
    let hasMore: Bool
    let isLoadingPage: Bool
    let pageError: AppError?
}

private extension MovieDetailContent {
    func withFullscreen(_ fullscreen: FullscreenImages?) -> MovieDetailContent {
        MovieDetailContent(
            detail: detail,
            isFavorite: isFavorite,
            formattedRating: formattedRating,
            ratingAccessibilityLabel: ratingAccessibilityLabel,
            formattedBudget: formattedBudget,
            budgetAccessibilityLabel: budgetAccessibilityLabel,
            formattedRevenue: formattedRevenue,
            revenueAccessibilityLabel: revenueAccessibilityLabel,
            formattedReleaseDate: formattedReleaseDate,
            images: images,
            cast: cast,
            crew: crew,
            similar: similar,
            collection: collection,
            reviews: reviews,
            fullscreenImages: fullscreen
        )
    }

    func replacing(isFavorite: Bool) -> MovieDetailContent {
        MovieDetailContent(
            detail: detail,
            isFavorite: isFavorite,
            formattedRating: formattedRating,
            ratingAccessibilityLabel: ratingAccessibilityLabel,
            formattedBudget: formattedBudget,
            budgetAccessibilityLabel: budgetAccessibilityLabel,
            formattedRevenue: formattedRevenue,
            revenueAccessibilityLabel: revenueAccessibilityLabel,
            formattedReleaseDate: formattedReleaseDate,
            images: images,
            cast: cast,
            crew: crew,
            similar: similar,
            collection: collection,
            reviews: reviews,
            fullscreenImages: fullscreenImages
        )
    }

    func replacing(collection: CollectionSection?) -> MovieDetailContent {
        MovieDetailContent(
            detail: detail,
            isFavorite: isFavorite,
            formattedRating: formattedRating,
            ratingAccessibilityLabel: ratingAccessibilityLabel,
            formattedBudget: formattedBudget,
            budgetAccessibilityLabel: budgetAccessibilityLabel,
            formattedRevenue: formattedRevenue,
            revenueAccessibilityLabel: revenueAccessibilityLabel,
            formattedReleaseDate: formattedReleaseDate,
            images: images,
            cast: cast,
            crew: crew,
            similar: similar,
            collection: collection,
            reviews: reviews,
            fullscreenImages: fullscreenImages
        )
    }

    func replacing(reviews: ReviewsPatch) -> MovieDetailContent {
        MovieDetailContent(
            detail: detail,
            isFavorite: isFavorite,
            formattedRating: formattedRating,
            ratingAccessibilityLabel: ratingAccessibilityLabel,
            formattedBudget: formattedBudget,
            budgetAccessibilityLabel: budgetAccessibilityLabel,
            formattedRevenue: formattedRevenue,
            revenueAccessibilityLabel: revenueAccessibilityLabel,
            formattedReleaseDate: formattedReleaseDate,
            images: images,
            cast: cast,
            crew: crew,
            similar: similar,
            collection: collection,
            reviews: ReviewsSection(
                items: reviews.items,
                nextPage: reviews.nextPage,
                hasMore: reviews.hasMore,
                isLoadingPage: reviews.isLoadingPage,
                pageError: reviews.pageError
            ),
            fullscreenImages: fullscreenImages
        )
    }
}
