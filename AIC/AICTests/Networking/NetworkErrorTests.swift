//
//  NetworkErrorTests.swift
//  AICTests
//
//  Covers every branch of NetworkError.errorDescription.
//

import XCTest
@testable import AIC

final class NetworkErrorTests: XCTestCase {

    func test_invalidURL_errorDescription_isNonEmpty() {
        let description = NetworkError.invalidURL.errorDescription
        XCTAssertEqual(description, "The request URL could not be built.")
    }

    func test_transport_errorDescription_delegatesToURLError() {
        let urlError = URLError(.notConnectedToInternet)
        let description = NetworkError.transport(urlError).errorDescription
        XCTAssertEqual(description, urlError.localizedDescription)
    }

    func test_serverError_errorDescription_includesStatusCode() {
        let description = NetworkError.serverError(statusCode: 404).errorDescription
        XCTAssertEqual(description, "The server responded with an error (code 404).")
    }

    func test_decodingFailed_errorDescription_hidesUnderlyingDeveloperError() {
        let underlying = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "internal detail that must not leak to users")
        )
        let description = NetworkError.decodingFailed(underlying).errorDescription

        XCTAssertEqual(description, "The server response could not be read.")
        XCTAssertFalse(try XCTUnwrap(description).contains("internal detail"))
    }

    func test_unknown_errorDescription_delegatesToWrappedError() {
        let wrapped = URLError(.cancelled)
        let description = NetworkError.unknown(wrapped).errorDescription
        XCTAssertEqual(description, wrapped.localizedDescription)
    }

    func test_localizedDescription_usesErrorDescription() {
        // LocalizedError plumbing: .localizedDescription must route through errorDescription,
        // not the generic "The operation couldn't be completed" fallback.
        let error: Error = NetworkError.serverError(statusCode: 500)
        XCTAssertEqual(error.localizedDescription, "The server responded with an error (code 500).")
    }
}
