//
//  NavigationRouterTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class NavigationRouterTests: XCTestCase {

    func test_push_appendsRoute() {
        let router = NavigationRouter()

        router.push(.movieDetail(id: 278))

        XCTAssertEqual(router.path, [.movieDetail(id: 278)])
    }

    func test_pop_removesLastRoute() {
        let router = NavigationRouter()
        router.push(.movieDetail(id: 1))
        router.push(.movieDetail(id: 2))

        router.pop()

        XCTAssertEqual(router.path, [.movieDetail(id: 1)])
    }

    func test_popToDepth_truncatesPathForUIKitSync() {
        let router = NavigationRouter()
        router.push(.movieDetail(id: 1))
        router.push(.movieDetail(id: 2))

        router.pop(toDepth: 1)

        XCTAssertEqual(router.path, [.movieDetail(id: 1)])
    }

    func test_popToDepth_zeroClearsPath() {
        let router = NavigationRouter()
        router.push(.movieDetail(id: 1))

        router.pop(toDepth: 0)

        XCTAssertTrue(router.path.isEmpty)
    }

    func test_popToDepth_whenAlreadyAtDepth_isNoOp() {
        let router = NavigationRouter()
        router.push(.movieDetail(id: 1))

        router.pop(toDepth: 1)

        XCTAssertEqual(router.path, [.movieDetail(id: 1)])
    }

    // MARK: - Scene state restoration

    func test_routerSnapshot_codableRoundTrip() throws {
        let snapshot = RouterSnapshot(
            selectedTab: .favorites,
            topMoviesPath: [.movieDetail(id: 278)],
            favoritesPath: [
                .person(id: 5),
                .personCredits(personID: 5, personName: "Tim Robbins", department: .crew),
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RouterSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func test_appRouter_snapshot_reflectsTabAndPaths() {
        let router = AppRouter()
        router.selectedTab = .favorites
        router.topMovies.push(.movieDetail(id: 1))
        router.favorites.push(.person(id: 2))

        let snapshot = router.snapshot

        XCTAssertEqual(snapshot.selectedTab, .favorites)
        XCTAssertEqual(snapshot.topMoviesPath, [.movieDetail(id: 1)])
        XCTAssertEqual(snapshot.favoritesPath, [.person(id: 2)])
    }

    func test_appRouter_restore_setsTabAndPaths() {
        let router = AppRouter()

        router.restore(
            RouterSnapshot(
                selectedTab: .favorites,
                topMoviesPath: [.movieDetail(id: 9)],
                favoritesPath: [.person(id: 3)]
            )
        )

        XCTAssertEqual(router.selectedTab, .favorites)
        XCTAssertEqual(router.topMovies.path, [.movieDetail(id: 9)])
        XCTAssertEqual(router.favorites.path, [.person(id: 3)])
    }

    func test_routerStateStore_saveThenLoad_returnsSnapshot() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = RouterStateStore(defaults: defaults)
        let snapshot = RouterSnapshot(
            selectedTab: .favorites,
            topMoviesPath: [.movieDetail(id: 7)],
            favoritesPath: []
        )

        store.save(snapshot)
        XCTAssertEqual(store.load(), snapshot)

        store.clear()
        XCTAssertNil(store.load())
    }
}
