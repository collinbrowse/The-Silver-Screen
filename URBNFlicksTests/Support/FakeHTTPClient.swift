//
//  FakeHTTPClient.swift
//  URBNFlicksTests
//
//  The test seam for networking. Build real repositories over this — never
//  invent a MovieRepositoryProtocol. See .cursor/rules/testing.mdc.
//

import Foundation
@testable import URBNFlicks

struct FakeHTTPClient: HTTPClient, Sendable {
    enum Stub: Sendable {
        case success(Data, status: Int = 200)
        case failure(Error)
    }

    private let stub: Stub

    init(stub: Stub) {
        self.stub = stub
    }

    init(result: Result<Data, Error>, status: Int = 200) {
        switch result {
        case .success(let data):
            self.stub = .success(data, status: status)
        case .failure(let error):
            self.stub = .failure(error)
        }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        switch stub {
        case .success(let data, let status):
            let url = request.url ?? URL(string: "https://example.invalid")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}

/// Records requests while returning a fixed stub — use for endpoint assertions.
actor RecordingHTTPClient: HTTPClient {
    private let stub: FakeHTTPClient.Stub
    private(set) var requests: [URLRequest] = []

    init(stub: FakeHTTPClient.Stub) {
        self.stub = stub
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try await FakeHTTPClient(stub: stub).data(for: request)
    }

    var lastURL: URL? {
        requests.last?.url
    }

    var lastPath: String? {
        lastURL?.path
    }

    var lastAuthorizationHeader: String? {
        requests.last?.value(forHTTPHeaderField: "Authorization")
    }

    var requestCount: Int {
        requests.count
    }
}

/// Returns stubs in order — use to assert retry / eventual success.
actor SequencingHTTPClient: HTTPClient {
    private var stubs: [FakeHTTPClient.Stub]
    private(set) var requestCount = 0

    init(stubs: [FakeHTTPClient.Stub]) {
        self.stubs = stubs
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        guard !stubs.isEmpty else {
            throw URLError(.badServerResponse)
        }
        let stub = stubs.removeFirst()
        return try await FakeHTTPClient(stub: stub).data(for: request)
    }
}

/// Routes stubs by URL path fragment — use when one screen hits multiple endpoints.
actor RoutingHTTPClient: HTTPClient {
    private var routes: [String: FakeHTTPClient.Stub]
    private let fallback: FakeHTTPClient.Stub
    private(set) var requests: [URLRequest] = []

    init(routes: [String: FakeHTTPClient.Stub], fallback: FakeHTTPClient.Stub = .failure(URLError(.badURL))) {
        self.routes = routes
        self.fallback = fallback
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url?.path ?? ""
        let match = routes
            .compactMap { key, stub -> (key: String, stub: FakeHTTPClient.Stub, score: Int)? in
                guard let range = path.range(of: key) else { return nil }
                // Prefer matches that end later in the path, then longer keys.
                let end = path.distance(from: path.startIndex, to: range.upperBound)
                return (key, stub, end * 1_000 + key.count)
            }
            .max(by: { $0.score < $1.score })
        let stub = match?.stub ?? fallback
        return try await FakeHTTPClient(stub: stub).data(for: request)
    }

    var requestCount: Int { requests.count }
}
