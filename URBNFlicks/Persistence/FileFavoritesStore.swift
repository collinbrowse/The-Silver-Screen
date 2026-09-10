//
//  FileFavoritesStore.swift
//  URBNFlicks
//

import Foundation

/// On-disk favorites payload. The `version` field lets the schema evolve: a future field or
/// shape change bumps `currentVersion` and adds a migration case, instead of failing to decode
/// and making an existing user's whole Favorites list look broken.
private struct FavoritesFile: Codable {
    static let currentVersion = 1
    var version: Int
    var records: [FavoriteRecord]
}

actor FileFavoritesStore: FavoritesStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    static func applicationSupportURL(fileName: String = "favorites.json") throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("URBNFlicks", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    func load() async throws -> [FavoriteRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty {
            return []
        }

        // Current format: a versioned envelope.
        if let file = try? decoder.decode(FavoritesFile.self, from: data) {
            return migrate(file)
        }

        // Legacy format (version 0): a bare `[FavoriteRecord]`. Decode element-by-element and
        // skip any corrupt entry, so one bad record can't discard the rest.
        if let elements = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return elements.compactMap { element in
                guard let elementData = try? JSONSerialization.data(withJSONObject: element) else {
                    return nil
                }
                return try? decoder.decode(FavoriteRecord.self, from: elementData)
            }
        }

        // Unreadable file: quarantine it rather than throw or overwrite, so the user's data is
        // preserved for recovery, and start from an empty list.
        quarantineCorruptFile()
        return []
    }

    func save(_ records: [FavoriteRecord]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = FavoritesFile(version: FavoritesFile.currentVersion, records: records)
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Applies migrations to reach the current schema. Newer-than-current files are read as-is.
    private func migrate(_ file: FavoritesFile) -> [FavoriteRecord] {
        // Only version 1 exists today; future versions add cases here.
        file.records
    }

    private func quarantineCorruptFile() {
        let destination = fileURL.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
    }
}
