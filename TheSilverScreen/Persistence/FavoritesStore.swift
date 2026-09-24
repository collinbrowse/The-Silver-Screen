//
//  FavoritesStore.swift
//  TheSilverScreen
//

import Foundation

protocol FavoritesStore: Sendable {
    func load() async throws -> [FavoriteRecord]
    func save(_ records: [FavoriteRecord]) async throws
}
