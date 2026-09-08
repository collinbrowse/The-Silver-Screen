//
//  TMDBAPIKey.swift
//  URBNFlicks
//

import Foundation

enum TMDBAPIKey {
    enum KeyError: Error {
        case missing
    }

    static func fromBundle(_ bundle: Bundle = .main) throws -> String {
        guard let key = bundle.object(forInfoDictionaryKey: "TMDBAPIKey") as? String else {
            throw KeyError.missing
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            throw KeyError.missing
        }
        return trimmed
    }
}
