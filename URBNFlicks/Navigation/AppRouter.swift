//
//  AppRouter.swift
//  URBNFlicks
//

import Foundation

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .topMovies
    let topMovies: NavigationRouter
    let favorites: NavigationRouter

    init(
        selectedTab: AppTab = .topMovies,
        topMovies: NavigationRouter = NavigationRouter(),
        favorites: NavigationRouter = NavigationRouter()
    ) {
        self.selectedTab = selectedTab
        self.topMovies = topMovies
        self.favorites = favorites
    }

    func openFavorites() {
        selectedTab = .favorites
    }
}
