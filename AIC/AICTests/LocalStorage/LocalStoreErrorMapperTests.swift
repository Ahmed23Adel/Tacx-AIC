//
//  LocalStoreErrorMapperTests.swift
//  AICTests
//
//  Covers both branches of each mapping function — including the failure
//  branches that cannot be triggered through the store's public API.
//

import XCTest
@testable import AIC

final class LocalStoreErrorMapperTests: XCTestCase {

    private struct UnderlyingError: Error {}

    // MARK: - fetch

    func test_fetch_onSuccess_passesValueThrough() throws {
        let value = try LocalStoreErrorMapper.fetch { 42 }
        XCTAssertEqual(value, 42)
    }

    func test_fetch_onFailure_wrapsInFetchFailedPreservingUnderlying() {
        XCTAssertThrowsError(try LocalStoreErrorMapper.fetch { () -> Int in throw UnderlyingError() }) { error in
            guard case .fetchFailed(let underlying) = error as? LocalStoreError else {
                return XCTFail("Expected LocalStoreError.fetchFailed, got \(error)")
            }
            XCTAssertTrue(underlying is UnderlyingError)
        }
    }

    // MARK: - save

    func test_save_onSuccess_passesValueThrough() throws {
        let value = try LocalStoreErrorMapper.save { "saved" }
        XCTAssertEqual(value, "saved")
    }

    func test_save_onFailure_wrapsInSaveFailedPreservingUnderlying() {
        XCTAssertThrowsError(try LocalStoreErrorMapper.save { () -> Void in throw UnderlyingError() }) { error in
            guard case .saveFailed(let underlying) = error as? LocalStoreError else {
                return XCTFail("Expected LocalStoreError.saveFailed, got \(error)")
            }
            XCTAssertTrue(underlying is UnderlyingError)
        }
    }
}
