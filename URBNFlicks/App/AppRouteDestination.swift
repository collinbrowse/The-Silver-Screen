//
//  AppRouteDestination.swift
//  URBNFlicks
//

import SwiftUI

struct AppRouteDestination: View {
    let route: Route
    let movies: MovieRepository
    let people: PersonRepository
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let imageLoader: ImageLoader
    let router: NavigationRouter

    var body: some View {
        switch route {
        case .movieDetail(let id):
            MovieDetailRouteView(
                movieID: id,
                movies: movies,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                imageLoader: imageLoader,
                router: router
            )
        case .person(let id):
            PersonDetailRouteView(
                personID: id,
                people: people,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                imageLoader: imageLoader,
                router: router
            )
        case .personCredits(let personID, let personName, let department):
            CreditsListView(
                personID: personID,
                personName: personName,
                department: department,
                people: people,
                imageLoader: imageLoader,
                router: router
            )
        }
    }
}

struct MovieDetailRouteView: View {
    @State private var viewModel: MovieDetailViewModel
    let favoritesIndex: FavoritesIndex
    let imageLoader: ImageLoader
    let router: NavigationRouter

    init(
        movieID: Int,
        movies: MovieRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
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
        self.favoritesIndex = favoritesIndex
        self.imageLoader = imageLoader
        self.router = router
    }

    var body: some View {
        MovieDetailView(
            viewModel: viewModel,
            favoritesIndex: favoritesIndex,
            imageLoader: imageLoader,
            router: router
        )
    }
}

struct PersonDetailRouteView: View {
    @State private var viewModel: PersonDetailViewModel
    let favoritesIndex: FavoritesIndex
    let imageLoader: ImageLoader
    let router: NavigationRouter

    init(
        personID: Int,
        people: PersonRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: PersonDetailViewModel(
                personID: personID,
                people: people,
                favorites: favorites
            )
        )
        self.favoritesIndex = favoritesIndex
        self.imageLoader = imageLoader
        self.router = router
    }

    var body: some View {
        PersonDetailView(
            viewModel: viewModel,
            favoritesIndex: favoritesIndex,
            imageLoader: imageLoader,
            router: router
        )
    }
}
