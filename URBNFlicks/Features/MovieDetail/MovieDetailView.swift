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
        .background(MovieDetailTheme.canvas)
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
            VStack(alignment: .leading, spacing: MovieDetailSpacing.xl) {
                header(content)
                if !content.detail.genres.isEmpty {
                    genres(content.detail.genres)
                }
                ratingCard(content)
                overviewSection(content.detail.overview)
                factsCard(content)
            }
            .padding(.horizontal, MovieDetailSpacing.lg)
            .padding(.vertical, MovieDetailSpacing.lg)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .top) {
            if case .failed(let error) = activity {
                Text("\(error.title): \(error.message)")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(MovieDetailSpacing.sm)
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
                VStack(alignment: .leading, spacing: MovieDetailSpacing.md) {
                    MovieDetailPosterView(
                        posterPath: content.detail.posterPath,
                        imageLoader: imageLoader,
                        width: posterWidth
                    )
                    Text(content.detail.title)
                        .font(MovieDetailTypography.title)
                        .foregroundStyle(MovieDetailTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .top, spacing: MovieDetailSpacing.md) {
                    MovieDetailPosterView(
                        posterPath: content.detail.posterPath,
                        imageLoader: imageLoader,
                        width: posterWidth
                    )
                    Text(content.detail.title)
                        .font(MovieDetailTypography.title)
                        .foregroundStyle(MovieDetailTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.detail.title)
    }

    private func genres(_ genres: [MovieGenre]) -> some View {
        FlowLayout(spacing: MovieDetailSpacing.sm) {
            ForEach(genres) { genre in
                MovieDetailGenreChip(title: genre.name)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Genres: \(genres.map(\.name).joined(separator: ", "))")
    }

    private func ratingCard(_ content: MovieDetailContent) -> some View {
        MovieDetailSurfaceCard {
            HStack(spacing: MovieDetailSpacing.md) {
                Image(systemName: "star.fill")
                    .foregroundStyle(MovieDetailTheme.accent)
                    .accessibilityHidden(true)
                    .accessibilityLabel("")
                VStack(alignment: .leading, spacing: MovieDetailSpacing.xs) {
                    Text(content.formattedRating)
                        .font(MovieDetailTypography.ratingValue)
                        .foregroundStyle(MovieDetailTheme.textPrimary)
                    Text("TMDB RATING")
                        .font(MovieDetailTypography.factLabel)
                        .foregroundStyle(MovieDetailTheme.textMuted)
                        .tracking(0.6)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.ratingAccessibilityLabel)
    }

    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: MovieDetailSpacing.sm) {
            Text("Storyline")
                .font(MovieDetailTypography.section)
                .foregroundStyle(MovieDetailTheme.textPrimary)
            Text(overview.isEmpty ? "No description available." : overview)
                .font(MovieDetailTypography.body)
                .foregroundStyle(MovieDetailTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func factsCard(_ content: MovieDetailContent) -> some View {
        MovieDetailSurfaceCard {
            let stack = dynamicTypeSize.isAccessibilitySize
            Group {
                if stack {
                    VStack(alignment: .leading, spacing: MovieDetailSpacing.lg) {
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
                                .fill(MovieDetailTheme.separator.opacity(0.35))
                                .frame(width: 0.5)
                                .padding(.vertical, MovieDetailSpacing.xs)
                            factCell(label: "Revenue", value: content.formattedRevenue, accessibility: content.revenueAccessibilityLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, MovieDetailSpacing.lg)
                        }
                        Divider()
                            .padding(.vertical, MovieDetailSpacing.md)
                        factCell(label: "Release Date", value: content.formattedReleaseDate, accessibility: content.formattedReleaseDate)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func factCell(label: String, value: String, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: MovieDetailSpacing.xs) {
            Text(label.uppercased())
                .font(MovieDetailTypography.factLabel)
                .foregroundStyle(MovieDetailTheme.textMuted)
                .tracking(0.6)
            Text(value)
                .font(MovieDetailTypography.factValue)
                .foregroundStyle(MovieDetailTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(accessibility)")
    }
}

/// Simple wrapping layout for genre chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            width = max(width, x - spacing)
        }

        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}
