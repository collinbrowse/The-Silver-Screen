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
}
