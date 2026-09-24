//
//  AppDependencies.swift
//  TheSilverScreen
//

import Foundation

@MainActor
struct AppDependencies {
    let movies: MovieRepository
    let shows: TVRepository
    let people: PersonRepository
    let favorites: FavoritesRepository
    let favoritesIndex: FavoritesIndex
    let imageLoader: ImageLoader
    let router: AppRouter
    let logger: any AppLogging

    static func live() throws -> AppDependencies {
        let logger = OSAppLogger()
        let apiKey = try TMDBAPIKey.fromBundle()
        let httpClient = URLSessionHTTPClient()
        let movies = MovieRepository(
            client: httpClient,
            apiKey: apiKey,
            logger: logger
        )
        let people = PersonRepository(
            client: httpClient,
            apiKey: apiKey,
            logger: logger
        )
        let shows = TVRepository(
            client: httpClient,
            apiKey: apiKey,
            logger: logger
        )
        let favoritesStoreURL = try FileFavoritesStore.applicationSupportURL()
        let favoritesStore = FileFavoritesStore(fileURL: favoritesStoreURL)
        let favoritesIndex = FavoritesIndex()
        let favorites = FavoritesRepository(
            store: favoritesStore,
            logger: logger,
            index: favoritesIndex
        )
        let imageLoader = ImageLoader(client: URLSessionHTTPClient.images(), logger: logger)
        let router = AppRouter()
        return AppDependencies(
            movies: movies,
            shows: shows,
            people: people,
            favorites: favorites,
            favoritesIndex: favoritesIndex,
            imageLoader: imageLoader,
            router: router,
            logger: logger
        )
    }
}
