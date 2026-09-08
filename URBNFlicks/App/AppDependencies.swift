//
//  AppDependencies.swift
//  URBNFlicks
//

import Foundation

@MainActor
struct AppDependencies {
    let movies: MovieRepository
    let favorites: FavoritesRepository
    let imageLoader: ImageLoader
    let router: AppRouter
    let logger: any AppLogging

    static func live() throws -> AppDependencies {
        let logger = OSAppLogger()
        let apiKey = try TMDBAPIKey.fromBundle()
        let httpClient = URLSessionHTTPClient()
        let movies = MovieRepository(client: httpClient, apiKey: apiKey, logger: logger)
        let favoritesStoreURL = try FileFavoritesStore.applicationSupportURL()
        let favoritesStore = FileFavoritesStore(fileURL: favoritesStoreURL)
        let favorites = FavoritesRepository(store: favoritesStore, logger: logger)
        let imageLoader = ImageLoader(client: httpClient)
        let router = AppRouter()
        return AppDependencies(
            movies: movies,
            favorites: favorites,
            imageLoader: imageLoader,
            router: router,
            logger: logger
        )
    }
}
