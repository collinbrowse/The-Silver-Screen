//
//  RootTabView.swift
//  URBNFlicks
//

import SwiftUI

struct RootTabView: View {
    @Bindable var router: AppRouter
    let movies: MovieRepository
    let favorites: FavoritesRepository
    let imageLoader: ImageLoader
    let favoritesListViewModel: FavoritesListViewModel

    @State private var topMoviesViewModel: MovieListViewModel

    init(
        router: AppRouter,
        movies: MovieRepository,
        favorites: FavoritesRepository,
        imageLoader: ImageLoader,
        favoritesListViewModel: FavoritesListViewModel
    ) {
        self.router = router
        self.movies = movies
        self.favorites = favorites
        self.imageLoader = imageLoader
        self.favoritesListViewModel = favoritesListViewModel
        _topMoviesViewModel = State(initialValue: MovieListViewModel(movies: movies))
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TopMoviesListRepresentable(
                viewModel: topMoviesViewModel,
                imageLoader: imageLoader,
                favorites: favorites
            )
            .ignoresSafeArea()
            .tabItem {
                Label("Top Movies", systemImage: "film")
            }
            .tag(AppTab.topMovies)

            NavigationStack {
                FavoritesListView(
                    viewModel: favoritesListViewModel,
                    imageLoader: imageLoader,
                    favorites: favorites
                )
                .navigationTitle("Favorites")
            }
            .tabItem {
                Label("Favorites", systemImage: "heart")
            }
            .tag(AppTab.favorites)
        }
    }
}
