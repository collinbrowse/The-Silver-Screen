//
//  TVSeasonView.swift
//  TheSilverScreen
//

import SwiftUI

struct TVSeasonView: View {
    @Bindable var viewModel: TVSeasonViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    var router: NavigationRouter?
    let seriesID: Int
    let seasonNumber: Int

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
                    title: "Season Unavailable",
                    message: "This season could not be shown.",
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
                        name: content.seriesName,
                        isFavorite: favoritesIndex.contains(seriesID, kind: .tv)
                    ) {
                        Task { await toggleSeries(content) }
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
            return content.displayName
        }
        return ""
    }

    private func loaded(_ content: TVSeasonContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.xl) {
                header(content)
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
                if !content.directorsAndWriters.isEmpty {
                    TVCreditCarousel(
                        title: "Directors & Writers",
                        people: content.directorsAndWriters,
                        imageLoader: imageLoader
                    ) { person in
                        router?.push(.person(id: person.id))
                    }
                }
                if !content.episodes.isEmpty {
                    episodes(content.episodes, seriesName: content.seriesName)
                }
            }
            .padding(.vertical, DesignSpacing.lg)
            .coordinateSpace(.named("detailScroll"))
        }
        .scrollingInlineTitle(navigationTitle)
    }

    private func header(_ content: TVSeasonContent) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            HStack(alignment: .top, spacing: DesignSpacing.md) {
                MoviePosterView(
                    posterPath: content.posterPath,
                    imageLoader: imageLoader,
                    width: 112
                )
                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    Text(content.seriesName)
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.textSecondary)
                    Text(content.displayName)
                        .font(DesignTypography.title)
                        .foregroundStyle(DesignTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .inlineTitleAnchor()
                    Text(content.formattedAirDate)
                        .font(DesignTypography.metadata)
                        .foregroundStyle(DesignTheme.textSecondary)
                }
            }
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

    private func toggleSeries(_ content: TVSeasonContent) async {
        _ = try? await favorites.toggle(
            tv: FavoriteTVSeries(
                id: seriesID,
                name: content.seriesName,
                posterPath: content.posterPath,
                releaseDate: nil,
                genreIDs: []
            )
        )
    }

    private func episodes(_ episodes: [TVEpisodeSummary], seriesName: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Episodes")
                .font(DesignTypography.section)
                .foregroundStyle(DesignTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, DesignSpacing.lg)

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
                    episodeRow(episode)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignSpacing.lg)
            }
        }
    }

    private func episodeRow(_ episode: TVEpisodeSummary) -> some View {
        HStack(alignment: .top, spacing: DesignSpacing.md) {
            RemoteImageView(
                path: episode.stillPath,
                kind: .backdrop,
                width: 120,
                aspectRatio: 16 / 9,
                imageLoader: imageLoader,
                placeholderSystemImage: "tv"
            )
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(episode.title)
                    .font(DesignTypography.metadata.weight(.semibold))
                    .foregroundStyle(DesignTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Episode \(episode.episodeNumber)")
                    .font(DesignTypography.chip)
                    .foregroundStyle(DesignTheme.textSecondary)
                if !episode.overview.isEmpty {
                    Text(episode.overview)
                        .font(DesignTypography.chip)
                        .foregroundStyle(DesignTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(DisplayDate.day(episode.airDate))
                    .font(DesignTypography.chip)
                    .foregroundStyle(DesignTheme.textSecondary)
                Text(episode.directorLine)
                    .font(DesignTypography.chip)
                    .foregroundStyle(DesignTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(episodeLabel(episode))
        .accessibilityAddTraits(.isButton)
    }

    private func episodeLabel(_ episode: TVEpisodeSummary) -> String {
        let director = episode.directorLine
        return "\(episode.title), Episode \(episode.episodeNumber), \(DisplayDate.day(episode.airDate)), \(director)"
    }
}
