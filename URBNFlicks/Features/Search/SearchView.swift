//
//  SearchView.swift
//  URBNFlicks
//
//  Search tab: Movies, TV, and People segments. The field is the system
//  search UI; dismissing the keyboard leaves the current results in place.
//

import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    var isSearchPresented: Binding<Bool> = .constant(false)
    var router: NavigationRouter?

    @State private var scrollIDs: [SearchScope: Int] = [:]

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                Button {
                    isSearchPresented.wrappedValue = false
                } label: {
                    EmptyStateView(
                        title: viewModel.emptyTitle,
                        message: viewModel.emptyMessage,
                        systemImage: "magnifyingglass"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    viewModel.showsFocusedPlaceholder
                        ? "Dismisses search and restores the last results"
                        : ""
                )
            case .loaded(let listing, let activity):
                results(listing, activity: activity)
            case .failed(let error):
                ErrorStateView(error: error) {
                    await viewModel.retry()
                }
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            Picker("Search", selection: $viewModel.scope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSpacing.lg)
            .padding(.vertical, DesignSpacing.sm)
            .accessibilityLabel("Search category")
        }
        .background(DesignTheme.canvas)
        .navigationTitle("Search")
        .onChange(of: viewModel.query) { _, _ in
            Task { await viewModel.commitQueryChange() }
        }
        .onChange(of: viewModel.scope) { _, _ in
            Task { await viewModel.reloadForScopeChange() }
        }
        .onChange(of: isSearchPresented.wrappedValue) { _, focused in
            viewModel.setFieldFocused(focused)
        }
        .onChange(of: viewModel.committedQuery) { _, _ in
            scrollIDs = [:]
        }
        .refreshable { await viewModel.refresh() }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func results(_ listing: SearchListing, activity: LoadActivity) -> some View {
        List {
            switch listing {
            case .movies(let rows):
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    resultButton(index: index, count: rows.count, rowID: row.id) {
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
                    } star: {
                        favoriteStar(name: row.title, id: row.id, kind: .movie) {
                            try? await favorites.toggle(movie: row.asMovie())
                        }
                    }
                }
            case .tv(let rows):
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    resultButton(index: index, count: rows.count, rowID: row.id) {
                        router?.push(.tvSeries(id: row.id))
                    } label: {
                        CatalogRowView(
                            title: row.name,
                            subtitle: row.genreNames.joined(separator: ", "),
                            metadata: row.formattedFirstAirDate,
                            imagePath: row.posterPath,
                            imageKind: .poster,
                            placeholderSystemImage: "tv",
                            imageLoader: imageLoader
                        )
                    } star: {
                        favoriteStar(name: row.name, id: row.id, kind: .tv) {
                            try? await favorites.toggle(tv: row.asSeries())
                        }
                    }
                }
            case .people(let rows):
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    resultButton(index: index, count: rows.count, rowID: row.id) {
                        router?.push(.person(id: row.id))
                    } label: {
                        CatalogRowView(
                            title: row.name,
                            subtitle: "",
                            metadata: row.knownForDepartment ?? "",
                            imagePath: row.profilePath,
                            imageKind: .profile,
                            placeholderSystemImage: "person.fill",
                            imageLoader: imageLoader
                        )
                    } star: {
                        favoriteStar(name: row.name, id: row.id, kind: .person) {
                            try? await favorites.toggle(person: row.asPerson())
                        }
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
        .scrollPosition(id: Binding(
            get: { scrollIDs[viewModel.scope] },
            set: { scrollIDs[viewModel.scope] = $0 }
        ))
        .overlay(alignment: .top) {
            LoadActivityBanner(activity: activity)
        }
    }

    private func resultButton<Label: View, Star: View>(
        index: Int,
        count: Int,
        rowID: Int,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label,
        @ViewBuilder star: () -> Star
    ) -> some View {
        HStack(alignment: .center, spacing: DesignSpacing.sm) {
            Button(action: action) {
                label()
            }
            .buttonStyle(.plain)
            star()
        }
        .id(rowID)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8))
        .onAppear {
            if index == count - 1 {
                Task { await viewModel.loadMore() }
            }
        }
    }

    private func favoriteStar(
        name: String,
        id: Int,
        kind: FavoriteKind,
        toggle: @escaping () async -> Void
    ) -> some View {
        CellFavoriteStar(
            name: name,
            isFavorite: favoritesIndex.contains(id, kind: kind)
        ) {
            Task { await toggle() }
        }
    }
}
