//
//  InMemoryAnnotationsStore.swift
//  TheSilverScreenTests
//

import Foundation
@testable import TheSilverScreen

actor InMemoryAnnotationsStore: AnnotationsStore {
    private var records: [MediaAnnotation]
    var loadError: Error?
    var saveError: Error?

    init(records: [MediaAnnotation] = []) {
        self.records = records
    }

    func load() async throws -> [MediaAnnotation] {
        if let loadError {
            throw loadError
        }
        return records
    }

    func save(_ records: [MediaAnnotation]) async throws {
        if let saveError {
            throw saveError
        }
        self.records = records
    }

    func setSaveError(_ error: Error?) {
        saveError = error
    }
}
