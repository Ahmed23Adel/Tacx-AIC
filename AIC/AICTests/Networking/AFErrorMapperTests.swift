//
//  AFErrorMapperTests.swift
//  AICTests
//
//  Covers every branch of AFErrorMapper, including the two that cannot be
//  produced through AlamofireAPIRequester.send() with a valid baseURL
//  (.invalidURL and .unknown).
//

import XCTest
import Alamofire
@testable import AIC

final class AFErrorMapperTests: XCTestCase {

    private var sut: AFErrorMapper!

    override func setUp() {
        super.setUp()
        sut = AFErrorMapper()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: serverError

    func test_networkError_validationFailedWithStatusCode_mapsToServerError() {
        let afError = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))

        let result = sut.networkError(from: afError, statusCode: 404)

        guard case .serverError(let statusCode) = result else {
            return XCTFail("Expected .serverError, got \(result)")
        }
        XCTAssertEqual(statusCode, 404)
    }

    func test_networkError_validationFailedWithNilStatusCode_fallsThroughToUnknown() {
        // Branch guard: .serverError requires BOTH the case match and a status code
        let afError = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 500))

        let result = sut.networkError(from: afError, statusCode: nil)

        guard case .unknown = result else {
            return XCTFail("Expected .unknown when status code is missing, got \(result)")
        }
    }

    // MARK: decodingFailed

    func test_networkError_serializationFailed_mapsToDecodingFailed() {
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad json"))
        let afError = AFError.responseSerializationFailed(reason: .decodingFailed(error: decodingError))

        let result = sut.networkError(from: afError, statusCode: 200)

        guard case .decodingFailed = result else {
            return XCTFail("Expected .decodingFailed, got \(result)")
        }
    }

    // MARK: transport

    func test_networkError_sessionTaskFailedWithURLError_mapsToTransport() {
        let urlError = URLError(.notConnectedToInternet)
        let afError = AFError.sessionTaskFailed(error: urlError)

        let result = sut.networkError(from: afError, statusCode: nil)

        guard case .transport(let mapped) = result else {
            return XCTFail("Expected .transport, got \(result)")
        }
        XCTAssertEqual(mapped.code, .notConnectedToInternet)
    }

    func test_networkError_sessionTaskFailedWithNonURLError_doesNotMapToTransport() {
        struct SomeError: Error {}
        let afError = AFError.sessionTaskFailed(error: SomeError())

        let result = sut.networkError(from: afError, statusCode: nil)

        guard case .unknown = result else {
            return XCTFail("Expected .unknown for non-URLError underlying error, got \(result)")
        }
    }

    // MARK: invalidURL

    func test_networkError_invalidURL_mapsToInvalidURL() {
        let afError = AFError.invalidURL(url: "not a url")

        let result = sut.networkError(from: afError, statusCode: nil)

        guard case .invalidURL = result else {
            return XCTFail("Expected .invalidURL, got \(result)")
        }
    }

    // MARK: unknown

    func test_networkError_unclassifiedAFError_mapsToUnknown() {
        let afError = AFError.explicitlyCancelled

        let result = sut.networkError(from: afError, statusCode: nil)

        guard case .unknown = result else {
            return XCTFail("Expected .unknown, got \(result)")
        }
    }
}
