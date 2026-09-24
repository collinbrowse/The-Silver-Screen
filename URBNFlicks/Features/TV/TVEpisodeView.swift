//
//  TVEpisodeView.swift
//  URBNFlicks
//

import SwiftUI

struct TVEpisodeView: View {
    @Bindable var viewModel: TVEpisodeViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let seriesID: Int
    let seriesName: String
    let seasonNumber: Int
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
                    title: "Episode Unavailable",
                    message: "This episode could not be shown.",
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
            ToolbarItem(placement: .topBarTrailing) {
                CellFavoriteStar(
                    name: seriesName,
                    isFavorite: favoritesIndex.contains(seriesID, kind: .tv)
                ) {
                    Task {
                        _ = try? await favorites.toggle(
                            tv: FavoriteTVSeries(
                                id: seriesID,
                                name: seriesName,
                                posterPath: nil,
                                releaseDate: nil,
                                genreIDs: []
                            )
                        )
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
            return content.title
        }
        return ""
    }

    private func loaded(_ content: TVEpisodeContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.xl) {
                header(content)
                if !content.otherEpisodes.isEmpty {
                    otherEpisodes(content.otherEpisodes)
                }
                if !content.images.isEmpty {
                    TVImageCarousel(images: content.images, imageLoader: imageLoader) { image in
                        viewModel.openImages(initialID: image.id)
                    }
                }
                if !content.cast.isEmpty {
                    TVCreditCarousel(title: "Cast", people: content.cast, imageLoader: imageLoader) { person in
                        router?.push(.person(id: person.id))
                    }
                }
                if !content.guestStars.isEmpty {
                    TVCreditCarousel(
                        title: "Guest Stars",
                        people: content.guestStars,
                        imageLoader: imageLoader
                    ) { person in
                        router?.push(.person(id: person.id))
                    }
                }
                if !content.directorsAndWriters.isEmpty {
                    TVCreditCarousel(
                        title: "Directors & Writers",
                        people: content.directorsAndWriters,
                        imageLoader: imageLoader
                    ) { person in
                        router?.push(.person(id: person.id))
                    }
                }
            }
            .padding(.vertical, DesignSpacing.lg)
            .coordinateSpace(.named("detailScroll"))
        }
        .scrollingInlineTitle(navigationTitle)
    }

    private func header(_ content: TVEpisodeContent) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            RemoteImageView(
                path: content.stillPath,
                kind: .backdrop,
                width: 360,
                aspectRatio: 16 / 9,
                imageLoader: imageLoader,
                placeholderSystemImage: "tv"
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(content.title)
                .font(DesignTypography.title)
                .foregroundStyle(DesignTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .inlineTitleAnchor()
            Text(content.episodeNumberText)
                .font(DesignTypography.metadata.weight(.semibold))
                .foregroundStyle(DesignTheme.textSecondary)
            Text(content.formattedAirDate)
                .font(DesignTypography.metadata)
                .foregroundStyle(DesignTheme.textSecondary)
            if !content.overview.isEmpty {
                Text(content.overview)
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DesignSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    private func otherEpisodes(_ episodes: [TVEpisodeSummary]) -> some View {
        DetailCarousel(title: "More Episodes") {
            ForEach(episodes) { episode in
                Button {
                    router?.push(
                        .tvEpisode(
                            seriesID: seriesID,
                            seriesName: seriesName,
                            seasonNumber: seasonNumber,
                            episodeNumber: episode.episodeNumber
                        )
                    )
                } label: {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        RemoteImageView(
                            path: episode.stillPath,
                            kind: .backdrop,
                            width: 200,
                            aspectRatio: 16 / 9,
                            imageLoader: imageLoader,
                            placeholderSystemImage: "tv"
                        )
                        .carouselCard(width: 200, aspectRatio: 16 / 9)
                        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                            Text(episode.title)
                                .font(DesignTypography.metadata.weight(.semibold))
                                .foregroundStyle(DesignTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Episode \(episode.episodeNumber)")
                                .font(DesignTypography.chip)
                                .foregroundStyle(DesignTheme.textSecondary)
                        }
                        .frame(width: 200, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(episode.title), Episode \(episode.episodeNumber)")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
