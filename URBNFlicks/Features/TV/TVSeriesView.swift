//
//  TVSeriesView.swift
//  URBNFlicks
//

import SwiftUI

struct TVSeriesView: View {
    @Bindable var viewModel: TVSeriesViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    var router: NavigationRouter?

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
                    title: "Series Unavailable",
                    message: "This series could not be shown.",
                    systemImage: "tv"
                )
            case .loaded(let content, _):
                loaded(content)
            case .failed(let error):
                ErrorStateView(error: error) {
                    await viewModel.retry()
                }
            }
        }
        .background(DesignTheme.canvas)
        .toolbar {
            if case .loaded(let content, _) = viewModel.state {
                ToolbarItem(placement: .topBarTrailing) {
                    CellFavoriteStar(
                        name: content.detail.name,
                        isFavorite: favoritesIndex.contains(content.detail.id, kind: .tv)
                    ) {
                        Task { await toggleFavorite(content.detail) }
                    }
                }
            }
        }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
        .fullScreenCover(item: fullscreenBinding) { selection in
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

    private var navigationTitle: String {
        if case .loaded(let content, _) = viewModel.state {
            return content.detail.name
        }
        return ""
    }

    private func loaded(_ content: TVSeriesContent) -> some View {
        ScrollViewReader { proxy in
            seriesScroll(content, scrollTo: { id in
                proxy.scrollTo(id, anchor: .top)
            })
        }
    }

    private func seriesScroll(_ content: TVSeriesContent, scrollTo: @escaping (String) -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.xl) {
                header(content)
                if !content.detail.images.isEmpty {
                    TVImageCarousel(images: content.detail.images, imageLoader: imageLoader) { image in
                        viewModel.openImages(initialID: image.id)
                    }
                }
                if !content.seasons.isEmpty {
                    seasonsCarousel(content)
                }
                if !content.recommendations.isEmpty {
                    recommendationsCarousel(content)
                }
                if !content.detail.cast.isEmpty {
                    TVCreditCarousel(
                        title: "Cast",
                        people: content.detail.cast,
                        imageLoader: imageLoader
                    ) { person in
                        router?.push(.person(id: person.id))
                    }
                }
                if !content.detail.directorsAndWriters.isEmpty {
                    TVCreditCarousel(
                        title: "Directors & Writers",
                        people: content.detail.directorsAndWriters,
                        imageLoader: imageLoader
                    ) { person in
                        router?.push(.person(id: person.id))
                    }
                }
                if let reviews = content.reviews {
                    ReviewPageList(
                        items: reviews.items,
                        hasMore: reviews.hasMore,
                        totalCount: reviews.totalCount,
                        isLoadingPage: reviews.isLoadingPage,
                        pageError: reviews.pageError,
                        loadMore: { await viewModel.loadMoreReviews() },
                        scrollTo: scrollTo
                    )
                }
            }
            .padding(.vertical, DesignSpacing.lg)
            .coordinateSpace(.named("detailScroll"))
        }
        .scrollingInlineTitle(navigationTitle)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func toggleFavorite(_ detail: TVSeriesDetail) async {
        _ = try? await favorites.toggle(
            tv: FavoriteTVSeries(
                id: detail.id,
                name: detail.name,
                posterPath: detail.posterPath,
                releaseDate: detail.firstAirDate,
                genreIDs: detail.genres.map(\.id)
            )
        )
    }

    private func header(_ content: TVSeriesContent) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            HStack(alignment: .top, spacing: DesignSpacing.md) {
                MoviePosterView(
                    posterPath: content.detail.posterPath,
                    imageLoader: imageLoader,
                    width: 112
                )
                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    Text(content.detail.name)
                        .font(DesignTypography.title)
                        .foregroundStyle(DesignTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("First aired \(content.formattedFirstAirDate)")
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.textSecondary)
                    Text(content.formattedLastAirDate)
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.textSecondary)
                    Text(content.creatorsText)
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !content.detail.genres.isEmpty {
                Text(content.detail.genres.map(\.name).joined(separator: ", "))
                    .font(DesignTypography.chip)
                    .foregroundStyle(DesignTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !content.detail.overview.isEmpty {
                Text(content.detail.overview)
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DesignSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    private func seasonsCarousel(_ content: TVSeriesContent) -> some View {
        DetailCarousel(title: "Seasons") {
            ForEach(content.seasons) { season in
                Button {
                    router?.push(
                        .tvSeason(
                            seriesID: content.detail.id,
                            seriesName: content.detail.name,
                            seasonNumber: season.seasonNumber
                        )
                    )
                } label: {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        RemoteImageView(
                            path: season.posterPath,
                            kind: .poster,
                            width: 140,
                            aspectRatio: 2 / 3,
                            imageLoader: imageLoader,
                            placeholderSystemImage: "tv"
                        )
                        .carouselCard(width: 140, aspectRatio: 2 / 3)
                        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                            Text(season.name)
                                .font(DesignTypography.metadata.weight(.semibold))
                                .foregroundStyle(DesignTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(season.formattedAirDate)
                                .font(DesignTypography.chip)
                                .foregroundStyle(DesignTheme.textSecondary)
                            Text(season.episodeCountText)
                                .font(DesignTypography.chip)
                                .foregroundStyle(DesignTheme.textSecondary)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(season.name), \(season.formattedAirDate), \(season.episodeCountText)")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func recommendationsCarousel(_ content: TVSeriesContent) -> some View {
        DetailCarousel(title: "Recommendations") {
            ForEach(content.recommendations) { show in
                Button {
                    router?.push(.tvSeries(id: show.id))
                } label: {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        MoviePosterView(
                            posterPath: show.posterPath,
                            imageLoader: imageLoader,
                            width: 140
                        )
                        Text(show.name)
                            .font(DesignTypography.metadata.weight(.semibold))
                            .foregroundStyle(DesignTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 140, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(show.name)
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
