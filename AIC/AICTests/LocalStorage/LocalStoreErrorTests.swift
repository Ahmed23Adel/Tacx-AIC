//
//  LocalStoreErrorTests.swift
//  AICTests
//
//  Covers every branch of LocalStoreError.errorDescription.
//

import XCTest
@testable import AIC

final class LocalStoreErrorTests: XCTestCase {

    private struct AnyUnderlying: Error {}

    func test_fetchFailed_errorDescription_isUserSafe() {
        let description = LocalStoreError.fetchFailed(underlying: AnyUnderlying()).errorDescription
        XCTAssertEqual(description, "Saved data could not be read.")
    }

    func test_saveFailed_errorDescription_isUserSafe() {
        let description = LocalStoreError.saveFailed(underlying: AnyUnderlying()).errorDescription
        XCTAssertEqual(description, "Data could not be saved on this device.")
    }

    func test_localizedDescription_usesErrorDescription() {
        // LocalizedError plumbing: .localizedDescription must route through
        // errorDescription, not the generic NSError fallback.
        let error: Error = LocalStoreError.fetchFailed(underlying: AnyUnderlying())
        XCTAssertEqual(error.localizedDescription, "Saved data could not be read.")
    }
}
