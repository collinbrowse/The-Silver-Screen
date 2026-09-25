//
//  AppRouteDestination.swift
//  TheSilverScreen
//

import SwiftUI

struct AppRouteDestination: View {
    let route: Route
    let movies: MovieRepository
    let shows: TVRepository
    let people: PersonRepository
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let annotations: AnnotationsRepository
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
                annotations: annotations,
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
        case .collection(let id):
            CollectionRouteView(
                collectionID: id,
                movies: movies,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                annotations: annotations,
                imageLoader: imageLoader,
                router: router
            )
        case .tvSeries(let id):
            TVSeriesRouteView(
                seriesID: id,
                shows: shows,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                annotations: annotations,
                imageLoader: imageLoader,
                router: router
            )
        case .tvSeason(let seriesID, let seriesName, let seasonNumber):
            TVSeasonRouteView(
                seriesID: seriesID,
                seriesName: seriesName,
                seasonNumber: seasonNumber,
                shows: shows,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                annotations: annotations,
                imageLoader: imageLoader,
                router: router
            )
        case .tvEpisode(let seriesID, let seriesName, let seasonNumber, let episodeNumber):
            TVEpisodeRouteView(
                seriesID: seriesID,
                seriesName: seriesName,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                shows: shows,
                favorites: favorites,
                favoritesIndex: favoritesIndex,
                annotations: annotations,
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
        annotations: AnnotationsRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: MovieDetailViewModel(
                movieID: movieID,
                movies: movies,
                favorites: favorites,
                annotations: annotations
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

struct CollectionRouteView: View {
    @State private var viewModel: CollectionViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let router: NavigationRouter

    init(
        collectionID: Int,
        movies: MovieRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
        annotations: AnnotationsRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: CollectionViewModel(
                collectionID: collectionID,
                movies: movies,
                annotations: annotations
            )
        )
        self.imageLoader = imageLoader
        self.favorites = favorites
        self.favoritesIndex = favoritesIndex
        self.router = router
    }

    var body: some View {
        CollectionView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            favorites: favorites,
            favoritesIndex: favoritesIndex,
            router: router
        )
    }
}

struct TVSeriesRouteView: View {
    @State private var viewModel: TVSeriesViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let router: NavigationRouter

    init(
        seriesID: Int,
        shows: TVRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
        annotations: AnnotationsRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: TVSeriesViewModel(seriesID: seriesID, shows: shows, annotations: annotations)
        )
        self.imageLoader = imageLoader
        self.favorites = favorites
        self.favoritesIndex = favoritesIndex
        self.router = router
    }

    var body: some View {
        TVSeriesView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            favorites: favorites,
            favoritesIndex: favoritesIndex,
            router: router
        )
    }
}

struct TVSeasonRouteView: View {
    @State private var viewModel: TVSeasonViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let router: NavigationRouter
    let seriesID: Int
    let seasonNumber: Int

    init(
        seriesID: Int,
        seriesName: String,
        seasonNumber: Int,
        shows: TVRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
        annotations: AnnotationsRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: TVSeasonViewModel(
                seriesID: seriesID,
                seriesName: seriesName,
                seasonNumber: seasonNumber,
                shows: shows,
                annotations: annotations
            )
        )
        self.imageLoader = imageLoader
        self.favorites = favorites
        self.favoritesIndex = favoritesIndex
        self.router = router
        self.seriesID = seriesID
        self.seasonNumber = seasonNumber
    }

    var body: some View {
        TVSeasonView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            favorites: favorites,
            favoritesIndex: favoritesIndex,
            router: router,
            seriesID: seriesID,
            seasonNumber: seasonNumber
        )
    }
}

struct TVEpisodeRouteView: View {
    @State private var viewModel: TVEpisodeViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let seriesID: Int
    let seriesName: String
    let seasonNumber: Int
    let router: NavigationRouter

    init(
        seriesID: Int,
        seriesName: String,
        seasonNumber: Int,
        episodeNumber: Int,
        shows: TVRepository,
        favorites: FavoritesRepository,
        favoritesIndex: FavoritesIndex,
        annotations: AnnotationsRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        _viewModel = State(
            initialValue: TVEpisodeViewModel(
                seriesID: seriesID,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                shows: shows,
                annotations: annotations
            )
        )
        self.imageLoader = imageLoader
        self.favorites = favorites
        self.favoritesIndex = favoritesIndex
        self.seriesID = seriesID
        self.seriesName = seriesName
        self.seasonNumber = seasonNumber
        self.router = router
    }

    var body: some View {
        TVEpisodeView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            favorites: favorites,
            favoritesIndex: favoritesIndex,
            seriesID: seriesID,
            seriesName: seriesName,
            seasonNumber: seasonNumber,
            router: router
        )
    }
}
