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

    var body: some View {
        switch route {
        case .movieDetail(let id):
            MovieDetailRouteView(
                movieID: id,
                movies: movies,
                favorites: favorites,
                imageLoader: imageLoader
            )
        }
    }
}

struct MovieDetailRouteView: View {
    @State private var viewModel: MovieDetailViewModel
    let imageLoader: ImageLoader

    init(
        movieID: Int,
        movies: MovieRepository,
        favorites: FavoritesRepository,
        imageLoader: ImageLoader
    ) {
        _viewModel = State(
            initialValue: MovieDetailViewModel(
                movieID: movieID,
                movies: movies,
                favorites: favorites
            )
        )
        self.imageLoader = imageLoader
    }

    var body: some View {
        MovieDetailView(viewModel: viewModel, imageLoader: imageLoader)
    }
}
