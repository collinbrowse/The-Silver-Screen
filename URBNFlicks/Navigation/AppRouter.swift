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

    /// Serializable navigation state for scene restoration.
    var snapshot: RouterSnapshot {
        RouterSnapshot(
            selectedTab: selectedTab,
            topMoviesPath: topMovies.path,
            favoritesPath: favorites.path
        )
    }

    /// Restores a previously persisted navigation state. Call before the view tree is built so
    /// the restored path is present at first render.
    func restore(_ snapshot: RouterSnapshot) {
        selectedTab = snapshot.selectedTab
        topMovies.path = snapshot.topMoviesPath
        favorites.path = snapshot.favoritesPath
    }
}

/// Serializable snapshot of the selected tab and each tab's navigation path.
struct RouterSnapshot: Codable, Equatable, Sendable {
    var selectedTab: AppTab
    var topMoviesPath: [Route]
    var favoritesPath: [Route]
}

/// Persists `RouterSnapshot` across launches so a jetsam kill returns the user to where they
/// were (selected tab and pushed detail screens) instead of the root.
struct RouterStateStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "com.urbn.URBNFlicks.router.snapshot") {
        self.defaults = defaults
        self.key = key
    }

    func save(_ snapshot: RouterSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func load() -> RouterSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RouterSnapshot.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
