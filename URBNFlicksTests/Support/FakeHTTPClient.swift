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
