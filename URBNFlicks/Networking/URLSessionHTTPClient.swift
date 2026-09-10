//
//  URLSessionHTTPClient.swift
//  URBNFlicks
//

import Foundation

struct URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession

    init(session: URLSession = URLSessionHTTPClient.makeSession()) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    private static func makeSession() -> URLSession {
        URLSession(configuration: makeConfiguration())
    }

    /// Shared transport configuration. `waitsForConnectivity` lets a request made in a dead zone
    /// wait for a network rather than failing instantly — but on its own that means a cold load in
    /// airplane mode spins forever behind a full-screen spinner, because the offline error never
    /// arrives. `timeoutIntervalForResource` bounds that wait so the request eventually fails and
    /// the UI can offer retry.
    static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        return configuration
    }
}
