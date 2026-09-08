//
//  InMemoryFavoritesStore.swift
//  URBNFlicksTests
//

import Foundation
@testable import URBNFlicks

actor InMemoryFavoritesStore: FavoritesStore {
    private var records: [FavoriteRecord]
    var loadError: Error?
    var saveError: Error?

    init(records: [FavoriteRecord] = []) {
        self.records = records
    }

    func load() async throws -> [FavoriteRecord] {
        if let loadError {
            throw loadError
        }
        return records
    }

    func save(_ records: [FavoriteRecord]) async throws {
        if let saveError {
            throw saveError
        }
        self.records = records
    }

    func setLoadError(_ error: Error?) {
        loadError = error
    }

    func setSaveError(_ error: Error?) {
        saveError = error
    }
}
