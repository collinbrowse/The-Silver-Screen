//
//  BrowseListView.swift
//  URBNFlicks
//
//  Movies, TV, and the mixed list. Media spans the width under the title.
//  Window and sort live in the Filters menu. The star is its own control.
//

import SwiftUI
import UIKit

struct BrowseListView: View {
    @Bindable var viewModel: BrowseListViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    var router: NavigationRouter?

    @State private var scrolledID: String?

    var body: some View {
        content
            .safeAreaBar(edge: .top, spacing: DesignSpacing.sm) {
                mediaControl
            }
            .background(DesignTheme.canvas)
            .navigationTitle("Browse")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .refreshable { await viewModel.refresh() }
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
        .onChange(of: viewModel.selectionToken) { _, _ in
            scrolledID = nil
        }
    }

    private var mediaControl: some View {
        FittingSegmentedControl(
            title: "Media",
            options: BrowseMedia.allCases,
            selection: Binding(
                get: { viewModel.media },
                set: { newValue in Task { await viewModel.setMedia(newValue) } }
            ),
            label: { $0.title },
            symbol: { $0.symbol }
        )
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.top, DesignSpacing.sm)
    }

    /// Window and sort, in the trailing navigation-bar slot.
    private var filterMenu: some View {
        Menu {
            Picker("Window", selection: windowSelection) {
                ForEach(BrowseWindow.allCases, id: \.self) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.inline)

            Picker("Sort", selection: sortSelection) {
                ForEach(BrowseSort.allCases, id: \.self) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filters")
        .accessibilityValue("\(viewModel.window.title), \(viewModel.sort.title)")
    }

    private var windowSelection: Binding<BrowseWindow> {
        Binding(
            get: { viewModel.window },
            set: { newValue in Task { await viewModel.setWindow(newValue) } }
        )
    }

    private var sortSelection: Binding<BrowseSort> {
        Binding(
            get: { viewModel.sort },
            set: { newValue in Task { await viewModel.setSort(newValue) } }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                title: "Nothing to Browse",
                message: "No titles match \(viewModel.media.title), \(viewModel.window.title).",
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

    private func list(_ rows: [BrowseRow], activity: LoadActivity) -> some View {
        List {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .center, spacing: DesignSpacing.sm) {
                    Button {
                        open(row)
                    } label: {
                        CatalogRowView(
                            title: row.title,
                            subtitle: row.genreLine,
                            metadata: row.formattedDate,
                            imagePath: row.posterPath,
                            imageKind: .poster,
                            placeholderSystemImage: row.media == .movie ? "film" : "tv",
                            imageLoader: imageLoader
                        )
                    }
                    .buttonStyle(.plain)

                    CellFavoriteStar(
                        name: row.title,
                        isFavorite: favoritesIndex.contains(
                            row.mediaID,
                            kind: row.media == .movie ? .movie : .tv
                        )
                    ) {
                        Task { await toggleFavorite(row) }
                    }
                }
                .id(row.id)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8))
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
        .scrollPosition(id: $scrolledID)
        .overlay(alignment: .top) {
            LoadActivityBanner(activity: activity)
        }
    }

    private func open(_ row: BrowseRow) {
        switch row.media {
        case .movie:
            router?.push(.movieDetail(id: row.mediaID))
        case .tv:
            router?.push(.tvSeries(id: row.mediaID))
        }
    }

    private func toggleFavorite(_ row: BrowseRow) async {
        switch row.media {
        case .movie:
            try? await favorites.toggle(movie: row.asMovie())
        case .tv:
            try? await favorites.toggle(tv: row.asSeries())
        }
    }
}

/// Segmented control that keeps the words while they fit, and switches to icons when they do not.
private struct FittingSegmentedControl<Option: Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    let symbol: (Option) -> String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var useIcons = false
    @State private var width: CGFloat = 0

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                if useIcons {
                    Image(systemName: symbol(option))
                        .accessibilityLabel(label(option))
                        .tag(option)
                } else {
                    Text(label(option))
                        .tag(option)
                }
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(title)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        width = newWidth
                    }
            }
        }
        .onChange(of: width) { _, _ in refit() }
        .onChange(of: dynamicTypeSize) { _, _ in refit() }
        .onAppear { refit() }
    }

    private func refit() {
        guard width > 0 else { return }
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        let textWidth = options.reduce(CGFloat(0)) { total, option in
            let size = (label(option) as NSString).size(withAttributes: [.font: font])
            return total + size.width
        }
        let padding = CGFloat(options.count) * 18
        useIcons = textWidth + padding > width
    }
}
