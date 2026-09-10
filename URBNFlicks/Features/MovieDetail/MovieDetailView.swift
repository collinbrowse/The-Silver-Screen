//
//  MovieDetailView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

struct MovieDetailView: View {
    @State var viewModel: MovieDetailViewModel
    let imageLoader: ImageLoader
    var router: NavigationRouter?
    var showsToolbarFavorite: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let backdropCardWidth: CGFloat = 280
    private let portraitCardWidth: CGFloat = 140

    private var fullscreenBinding: Binding<FullscreenImages?> {
        Binding(
            get: {
                if case .loaded(let content, _) = viewModel.state {
                    return content.fullscreenImages
                }
                return nil
            },
            set: { newValue in
                if newValue == nil {
                    viewModel.dismissImages()
                }
            }
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                EmptyStateView(
                    title: "Movie Unavailable",
                    message: "This movie could not be shown.",
                    systemImage: "film"
                )
            case .loaded(let content, let activity):
                loadedBody(content: content, activity: activity)
            case .failed(let error):
                ErrorStateView(error: error) {
                    await viewModel.retry()
                }
            }
        }
        .background(DesignTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsToolbarFavorite, case .loaded(let content, _) = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    CellFavoriteStar(
                        name: content.detail.title,
                        isFavorite: content.isFavorite
                    ) {
                        Task { await viewModel.toggleFavorite() }
                    }
                }
            }
        }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
        .fullScreenCover(item: showsToolbarFavorite ? fullscreenBinding : .constant(nil)) { selection in
            FullscreenImageViewer(
                images: selection.images,
                initialID: selection.initialID,
                imageKind: selection.kind,
                imageLoader: imageLoader
            ) {
                viewModel.dismissImages()
            }
        }
    }

    @ViewBuilder
    private func loadedBody(content: MovieDetailContent, activity: LoadActivity) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.xl) {
                metadataBlock(content)

                if let images = content.images {
                    imagesCarousel(images)
                }
                if let cast = content.cast {
                    castCarousel(cast, favoritePersonIDs: content.favoritePersonIDs)
                }
                if let crew = content.crew {
                    crewCarousel(crew, favoritePersonIDs: content.favoritePersonIDs)
                }
                if let similar = content.similar {
                    similarCarousel(similar, favoriteMovieIDs: content.favoriteMovieIDs)
                }
                if let collection = content.collection {
                    collectionCarousel(collection, favoriteMovieIDs: content.favoriteMovieIDs)
                }
                if let reviews = content.reviews {
                    reviewsSection(reviews)
                }
            }
            .padding(.vertical, DesignSpacing.lg)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectHidden(true)
        .overlay(alignment: .top) {
            if case .failed(let error) = activity {
                Text("\(error.title): \(error.message)")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(DesignSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .accessibilityLabel("\(error.title). \(error.message)")
            }
        }
        .accessibilityAction(.magicTap) {
            Task { await viewModel.toggleFavorite() }
        }
    }

    private func metadataBlock(_ content: MovieDetailContent) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xl) {
            header(content)
            if !content.detail.genres.isEmpty {
                genres(content.detail.genres)
            }
            ratingCard(content)
            overviewSection(content.detail.overview)
            factsCard(content)
        }
        .padding(.horizontal, DesignSpacing.lg)
    }

    // MARK: - Carousels

    private func imagesCarousel(_ section: MovieDetailContent.ImagesSection) -> some View {
        // Images has no caption stack under each card (unlike cast/crew/similar),
        // so add matching bottom air so the gap before the next section matches.
        DetailCarousel(title: "Images") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, image in
                RemoteImageView(
                    path: image.filePath,
                    kind: .backdrop,
                    width: backdropCardWidth,
                    aspectRatio: 16 / 9,
                    imageLoader: imageLoader,
                    placeholderSystemImage: "photo"
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.carousel, style: .continuous))
                .frame(width: backdropCardWidth, height: backdropCardWidth * 9 / 16)
                .contentShape(RoundedRectangle(cornerRadius: DesignRadius.carousel, style: .continuous))
                .onTapGesture {
                    viewModel.openImages(initialID: image.id)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Image \(index + 1) of \(section.items.count)")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    viewModel.openImages(initialID: image.id)
                }
            }
        }
        .padding(.bottom, DesignSpacing.xl)
    }

    private func castCarousel(
        _ section: MovieDetailContent.CastSection,
        favoritePersonIDs: Set<Int>
    ) -> some View {
        DetailCarousel(title: "Top Billed Cast") {
            ForEach(section.members) { member in
                Button {
                    router?.push(.person(id: member.personID))
                } label: {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        RemoteImageView(
                            path: member.profilePath,
                            kind: .profile,
                            width: portraitCardWidth,
                            aspectRatio: 2 / 3,
                            imageLoader: imageLoader,
                            placeholderSystemImage: "person.fill"
                        )
                        .carouselCard(width: portraitCardWidth, aspectRatio: 2 / 3)

                        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                            Text(member.name)
                                .font(DesignTypography.metadata.weight(.semibold))
                                .foregroundStyle(DesignTheme.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(member.character.isEmpty ? " " : member.character)
                                .font(DesignTypography.chip)
                                .foregroundStyle(DesignTheme.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(castAccessibilityLabel(member))
                    }
                    .frame(width: portraitCardWidth, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(router == nil)
                .overlay(alignment: .topTrailing) {
                    PersonFavoriteStar(
                        name: member.name,
                        isFavorite: favoritePersonIDs.contains(member.personID)
                    ) {
                        Task {
                            await viewModel.toggleFavorite(
                                person: FavoritePerson(
                                    id: member.personID,
                                    name: member.name,
                                    profilePath: member.profilePath,
                                    knownForDepartment: member.knownForDepartment
                                )
                            )
                        }
                    }
                    .padding(DesignSpacing.xs)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(router == nil ? [] : .isButton)
            }
        }
    }

    private func crewCarousel(
        _ section: MovieDetailContent.CrewSection,
        favoritePersonIDs: Set<Int>
    ) -> some View {
        DetailCarousel(title: "Directors & Writers") {
            ForEach(section.people) { person in
                Button {
                    router?.push(.person(id: person.id))
                } label: {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        RemoteImageView(
                            path: person.profilePath,
                            kind: .profile,
                            width: portraitCardWidth,
                            aspectRatio: 2 / 3,
                            imageLoader: imageLoader,
                            placeholderSystemImage: "person.fill"
                        )
                        .carouselCard(width: portraitCardWidth, aspectRatio: 2 / 3)

                        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                            Text(person.name)
                                .font(DesignTypography.metadata.weight(.semibold))
                                .foregroundStyle(DesignTheme.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(person.rolesLabel)
                                .font(DesignTypography.chip)
                                .foregroundStyle(DesignTheme.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(person.name), \(person.rolesLabel)")
                    }
                    .frame(width: portraitCardWidth, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(router == nil)
                .overlay(alignment: .topTrailing) {
                    PersonFavoriteStar(
                        name: person.name,
                        isFavorite: favoritePersonIDs.contains(person.id)
                    ) {
                        Task {
                            await viewModel.toggleFavorite(
                                person: FavoritePerson(
                                    id: person.id,
                                    name: person.name,
                                    profilePath: person.profilePath,
                                    knownForDepartment: person.knownForDepartment
                                )
                            )
                        }
                    }
                    .padding(DesignSpacing.xs)
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(router == nil ? [] : .isButton)
            }
        }
    }

    private func similarCarousel(
        _ section: MovieDetailContent.SimilarSection,
        favoriteMovieIDs: Set<Int>
    ) -> some View {
        DetailCarousel(title: "More Like This") {
            ForEach(section.items) { item in
                similarMovieCell(item, favoriteMovieIDs: favoriteMovieIDs)
            }
        }
    }

    private func collectionCarousel(
        _ section: MovieDetailContent.CollectionSection,
        favoriteMovieIDs: Set<Int>
    ) -> some View {
        DetailCarousel(title: section.title) {
            ForEach(section.movies) { movie in
                moviePosterCell(
                    movie: movie,
                    subtitle: nil,
                    favoriteMovieIDs: favoriteMovieIDs
                )
            }
        }
    }

    private func similarMovieCell(
        _ item: MovieDetailContent.SimilarSection.Item,
        favoriteMovieIDs: Set<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            MoviePosterView(
                posterPath: item.movie.posterPath,
                imageLoader: imageLoader,
                width: portraitCardWidth
            )
            .overlay(alignment: .topTrailing) {
                CellFavoriteStar(
                    name: item.movie.title,
                    isFavorite: favoriteMovieIDs.contains(item.movie.id)
                ) {
                    Task { await viewModel.toggleFavorite(movie: item.movie) }
                }
                .padding(DesignSpacing.xs)
            }

            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text(item.movie.title)
                    .font(DesignTypography.metadata.weight(.semibold))
                    .foregroundStyle(DesignTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.genreNames.isEmpty {
                    Text(item.genreNames.joined(separator: ", "))
                        .font(DesignTypography.chip)
                        .foregroundStyle(DesignTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if item.formattedReleaseDate != "Not available" {
                    Text(item.formattedReleaseDate)
                        .font(DesignTypography.chip)
                        .foregroundStyle(DesignTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(similarAccessibilityLabel(item))
            .accessibilityAddTraits(router == nil ? [] : .isButton)
        }
        .frame(width: portraitCardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            router?.push(.movieDetail(id: item.id))
        }
        .accessibilityElement(children: .contain)
    }

    private func moviePosterCell(
        movie: Movie,
        subtitle: String?,
        favoriteMovieIDs: Set<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            MoviePosterView(
                posterPath: movie.posterPath,
                imageLoader: imageLoader,
                width: portraitCardWidth
            )
            .overlay(alignment: .topTrailing) {
                CellFavoriteStar(
                    name: movie.title,
                    isFavorite: favoriteMovieIDs.contains(movie.id)
                ) {
                    Task { await viewModel.toggleFavorite(movie: movie) }
                }
                .padding(DesignSpacing.xs)
            }

            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text(movie.title)
                    .font(DesignTypography.metadata.weight(.semibold))
                    .foregroundStyle(DesignTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DesignTypography.chip)
                        .foregroundStyle(DesignTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(movie.title)
            .accessibilityAddTraits(router == nil ? [] : .isButton)
        }
        .frame(width: portraitCardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            router?.push(.movieDetail(id: movie.id))
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Reviews

    private func reviewsSection(_ section: MovieDetailContent.ReviewsSection) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Reviews")
                .font(DesignTypography.section)
                .foregroundStyle(DesignTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            LazyVStack(alignment: .leading, spacing: DesignSpacing.md) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, review in
                    ReviewRow(review: review)
                        .onAppear {
                            if index == section.items.count - 1 {
                                Task { await viewModel.loadMoreReviews() }
                            }
                        }
                }

                if section.isLoadingPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSpacing.sm)
                }

                if let error = section.pageError {
                    Text("\(error.title): \(error.message)")
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, DesignSpacing.lg)
    }

    // MARK: - Story 1 metadata

    @ViewBuilder
    private func header(_ content: MovieDetailContent) -> some View {
        let stackVertically = dynamicTypeSize.isAccessibilitySize
        let posterWidth: CGFloat = stackVertically ? 128 : 112
        let poster = posterThumbnail(path: content.detail.posterPath, width: posterWidth)

        Group {
            if stackVertically {
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    poster
                    Text(content.detail.title)
                        .font(DesignTypography.title)
                        .foregroundStyle(DesignTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .top, spacing: DesignSpacing.md) {
                    poster
                    Text(content.detail.title)
                        .font(DesignTypography.title)
                        .foregroundStyle(DesignTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.detail.title)
        .accessibilityHint(content.detail.posterPath == nil ? "" : "Shows the poster full screen")
        .accessibilityAction(named: "Show poster") {
            viewModel.openPoster()
        }
    }

    @ViewBuilder
    private func posterThumbnail(path: String?, width: CGFloat) -> some View {
        let poster = MoviePosterView(
            posterPath: path,
            imageLoader: imageLoader,
            width: width
        )
        if path != nil {
            poster
                .contentShape(RoundedRectangle(cornerRadius: DesignRadius.poster, style: .continuous))
                .onTapGesture {
                    viewModel.openPoster()
                }
                .accessibilityAddTraits(.isButton)
        } else {
            poster
        }
    }

    private func genres(_ genres: [MovieGenre]) -> some View {
        FlowLayout(spacing: DesignSpacing.sm) {
            ForEach(genres) { genre in
                TagChip(title: genre.name)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Genres: \(genres.map(\.name).joined(separator: ", "))")
    }

    private func ratingCard(_ content: MovieDetailContent) -> some View {
        SurfaceCard {
            HStack(spacing: DesignSpacing.md) {
                Image(systemName: "star.fill")
                    .foregroundStyle(DesignTheme.accent)
                    .accessibilityHidden(true)
                    .accessibilityLabel("")
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(content.formattedRating)
                        .font(DesignTypography.ratingValue)
                        .foregroundStyle(DesignTheme.textPrimary)
                    Text("TMDB RATING")
                        .font(DesignTypography.factLabel)
                        .foregroundStyle(DesignTheme.textMuted)
                        .tracking(0.6)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.ratingAccessibilityLabel)
    }

    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text("Storyline")
                .font(DesignTypography.section)
                .foregroundStyle(DesignTheme.textPrimary)
            Text(overview.isEmpty ? "No description available." : overview)
                .font(DesignTypography.body)
                .foregroundStyle(DesignTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func factsCard(_ content: MovieDetailContent) -> some View {
        SurfaceCard {
            let stack = dynamicTypeSize.isAccessibilitySize
            Group {
                if stack {
                    VStack(alignment: .leading, spacing: DesignSpacing.lg) {
                        factCell(label: "Budget", value: content.formattedBudget, accessibility: content.budgetAccessibilityLabel)
                        Divider()
                        factCell(label: "Revenue", value: content.formattedRevenue, accessibility: content.revenueAccessibilityLabel)
                        Divider()
                        factCell(label: "Release Date", value: content.formattedReleaseDate, accessibility: content.formattedReleaseDate)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 0) {
                            factCell(label: "Budget", value: content.formattedBudget, accessibility: content.budgetAccessibilityLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Rectangle()
                                .fill(DesignTheme.separator.opacity(0.35))
                                .frame(width: 0.5)
                                .padding(.vertical, DesignSpacing.xs)
                            factCell(label: "Revenue", value: content.formattedRevenue, accessibility: content.revenueAccessibilityLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, DesignSpacing.lg)
                        }
                        Divider()
                            .padding(.vertical, DesignSpacing.md)
                        factCell(label: "Release Date", value: content.formattedReleaseDate, accessibility: content.formattedReleaseDate)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func factCell(label: String, value: String, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            Text(label.uppercased())
                .font(DesignTypography.factLabel)
                .foregroundStyle(DesignTheme.textMuted)
                .tracking(0.6)
            Text(value)
                .font(DesignTypography.factValue)
                .foregroundStyle(DesignTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(accessibility)")
    }

    private func castAccessibilityLabel(_ member: CastMember) -> String {
        if member.character.isEmpty {
            return member.name
        }
        return "\(member.name) as \(member.character)"
    }

    private func similarAccessibilityLabel(_ item: MovieDetailContent.SimilarSection.Item) -> String {
        var parts = [item.movie.title]
        if !item.genreNames.isEmpty {
            parts.append(item.genreNames.joined(separator: ", "))
        }
        if item.formattedReleaseDate != "Not available" {
            parts.append(item.formattedReleaseDate)
        }
        return parts.joined(separator: ", ")
    }
}

private struct ReviewRow: View {
    let review: MovieReview
    @State private var expanded = false

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text(review.author)
                    .font(DesignTypography.metadata.weight(.semibold))
                    .foregroundStyle(DesignTheme.textPrimary)
                Text("@\(review.username)")
                    .font(DesignTypography.chip)
                    .foregroundStyle(DesignTheme.textSecondary)
                Text(MovieDetailViewModel.formatReviewDate(review.updatedAt))
                    .font(DesignTypography.chip)
                    .foregroundStyle(DesignTheme.textMuted)
                Text(review.content)
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignTheme.textSecondary)
                    .lineLimit(expanded ? nil : 6)
                    .fixedSize(horizontal: false, vertical: true)
                if review.content.count > 280 {
                    Button(expanded ? "Show Less" : "Show More") {
                        expanded.toggle()
                    }
                    .font(DesignTypography.chip.weight(.semibold))
                    .foregroundStyle(DesignTheme.accent)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(review.author), \(review.username), \(MovieDetailViewModel.formatReviewDate(review.updatedAt)). \(review.content)"
        )
    }
}
