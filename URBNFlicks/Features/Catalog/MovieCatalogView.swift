//
//  MovieCatalogView.swift
//  URBNFlicks
//
//  Shared list for Now Playing and Upcoming. Tapping a row pushes movie detail.
//

import SwiftUI

struct MovieCatalogView: View {
    @Bindable var viewModel: MovieCatalogViewModel
    let imageLoader: ImageLoader
    var router: NavigationRouter?

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                EmptyStateView(
                    title: "No Movies",
                    message: "Nothing is listed for \(viewModel.title) right now.",
                    systemImage: "film"
                )
            case .loaded(let rows, let activity):
                list(rows, activity: activity)
            case .failed(let error):
                ErrorStateView(error: error) {
                    await viewModel.retry()
                }
            }
        }
        .background(DesignTheme.canvas)
        .navigationTitle(viewModel.title)
        .refreshable { await viewModel.refresh() }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
    }

    private func list(_ rows: [CatalogMovieRow], activity: LoadActivity) -> some View {
        List {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Button {
                    router?.push(.movieDetail(id: row.id))
                } label: {
                    CatalogRowView(
                        title: row.title,
                        subtitle: row.genreNames.joined(separator: ", "),
                        metadata: row.formattedReleaseDate,
                        imagePath: row.posterPath,
                        imageKind: .poster,
                        placeholderSystemImage: "film",
                        imageLoader: imageLoader
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .onAppear {
                    if index == rows.count - 1 {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if activity == .loadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .top) {
            LoadActivityBanner(activity: activity)
        }
    }
}
