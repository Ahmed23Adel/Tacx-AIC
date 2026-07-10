//
//  MockAPIRequester.swift
//  AICTests
//

import Foundation
@testable import AIC

enum MockError: Error {
    case notStubbed
    case typeMismatch
}

final class MockAPIRequester: APIRequester {
    // Tracking
    private(set) var sendCallCount = 0
    private(set) var sentPaths: [String] = []
    private(set) var sentParameters: [[String: String]] = []

    // Stubbable result
    var stubbedResult: Result<Any, Error> = .failure(MockError.notStubbed)

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        sendCallCount += 1
        sentPaths.append(endpoint.path)
        sentParameters.append(endpoint.parameters)

        switch stubbedResult {
        case .success(let value):
            guard let typed = value as? E.Response else { throw MockError.typeMismatch }
            return typed
        case .failure(let error):
            throw error
        }
    }
}
