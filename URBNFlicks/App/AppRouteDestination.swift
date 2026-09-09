//
//  AppRouteDestination.swift
//  URBNFlicks
//

import SwiftUI

struct AppRouteDestination: View {
    let route: Route
    let movies: MovieRepository
    let favorites: FavoritesRepository
    let imageLoader: ImageLoader
    let router: NavigationRouter

    var body: some View {
        switch route {
        case .movieDetail(let id):
            MovieDetailRouteView(
                movieID: id,
                movies: movies,
                favorites: favorites,
                imageLoader: imageLoader,
                router: router
            )
        }
    }
}

struct MovieDetailRouteView: View {
    @State private var viewModel: MovieDetailViewModel
    let imageLoader: ImageLoader
    let router: NavigationRouter

    init(
        movieID: Int,
        movies: MovieRepository,
        favorites: FavoritesRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: MovieDetailViewModel(
                movieID: movieID,
                movies: movies,
                favorites: favorites
            )
        )
        self.imageLoader = imageLoader
        self.router = router
    }

    var body: some View {
        MovieDetailView(viewModel: viewModel, imageLoader: imageLoader, router: router)
    }
}
