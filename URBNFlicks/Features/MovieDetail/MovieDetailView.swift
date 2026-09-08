//
//  MovieDetailView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

struct MovieDetailView: View {
    @State var viewModel: MovieDetailViewModel
    let imageLoader: ImageLoader
    var showsToolbarFavorite: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    FavoriteStarButton(isFavorite: content.isFavorite) {
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
    }

    @ViewBuilder
    private func loadedBody(content: MovieDetailContent, activity: LoadActivity) -> some View {
        ScrollView {
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
            .padding(.vertical, DesignSpacing.lg)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
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

    @ViewBuilder
    private func header(_ content: MovieDetailContent) -> some View {
        let stackVertically = dynamicTypeSize.isAccessibilitySize
        let posterWidth: CGFloat = stackVertically ? 128 : 112

        Group {
            if stackVertically {
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    MoviePosterView(
                        posterPath: content.detail.posterPath,
                        imageLoader: imageLoader,
                        width: posterWidth
                    )
                    Text(content.detail.title)
                        .font(DesignTypography.title)
                        .foregroundStyle(DesignTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .top, spacing: DesignSpacing.md) {
                    MoviePosterView(
                        posterPath: content.detail.posterPath,
                        imageLoader: imageLoader,
                        width: posterWidth
                    )
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
}
