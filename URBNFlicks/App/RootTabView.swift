//
//  RootTabView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

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
                favorites: favorites,
                router: router.topMovies,
                makeDestination: makeUIKitDestination
            )
            .ignoresSafeArea()
            .tabItem {
                Label("Top Movies", systemImage: "film")
            }
            .tag(AppTab.topMovies)

            FavoritesTabRoot(
                router: router.favorites,
                viewModel: favoritesListViewModel,
                imageLoader: imageLoader,
                favorites: favorites,
                movies: movies
            )
            .tabItem {
                Label("Favorites", systemImage: "heart")
            }
            .tag(AppTab.favorites)
        }
    }

    @MainActor
    private func makeUIKitDestination(_ route: Route) -> UIViewController {
        switch route {
        case .movieDetail(let id):
            return MovieDetailHostingController(
                movieID: id,
                movies: movies,
                favorites: favorites,
                imageLoader: imageLoader,
                router: router.topMovies
            )
        }
    }
}

private struct FavoritesTabRoot: View {
    @Bindable var router: NavigationRouter
    @State var viewModel: FavoritesListViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let movies: MovieRepository

    var body: some View {
        NavigationStack(path: $router.path) {
            FavoritesListView(
                viewModel: viewModel,
                imageLoader: imageLoader
            )
            .navigationTitle("Favorites")
            .navigationDestination(for: Route.self) { route in
                AppRouteDestination(
                    route: route,
                    movies: movies,
                    favorites: favorites,
                    imageLoader: imageLoader,
                    router: router
                )
            }
        }
    }
}
