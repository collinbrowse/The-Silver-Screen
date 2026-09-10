//
//  RootTabView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

struct RootTabView: View {
    @Bindable var router: AppRouter
    let movies: MovieRepository
    let people: PersonRepository
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let imageLoader: ImageLoader
    let favoritesListViewModel: FavoritesListViewModel

    @State private var topMoviesViewModel: MovieListViewModel

    init(
        router: AppRouter,
        movies: MovieRepository,
        people: PersonRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
        imageLoader: ImageLoader,
        favoritesListViewModel: FavoritesListViewModel
    ) {
        self.router = router
        self.movies = movies
        self.people = people
        self.favorites = favorites
        self.favoritesIndex = favoritesIndex
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
                favoritesIndex: favoritesIndex,
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
                favoritesIndex: favoritesIndex,
                movies: movies,
                people: people
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
                favoritesIndex: favoritesIndex,
                imageLoader: imageLoader,
                router: router.topMovies
            )
        case .person(let id):
            return PersonHostingController(
                personID: id,
                people: people,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                imageLoader: imageLoader,
                router: router.topMovies
            )
        case .personCredits(let personID, let personName, let department):
            let root = CreditsListView(
                personID: personID,
                personName: personName,
                department: department,
                people: people,
                imageLoader: imageLoader,
                router: router.topMovies
            )
            let host = UIHostingController(rootView: root)
            switch department {
            case .cast: host.title = "Acting Roles"
            case .crew: host.title = "Crew Roles"
            }
            host.navigationItem.largeTitleDisplayMode = .never
            return host
        }
    }
}

private struct FavoritesTabRoot: View {
    @Bindable var router: NavigationRouter
    @Bindable var viewModel: FavoritesListViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let movies: MovieRepository
    let people: PersonRepository

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
                    people: people,
                    favorites: favorites,
                    favoritesIndex: favoritesIndex,
                    imageLoader: imageLoader,
                    router: router
                )
            }
        }
    }
}
