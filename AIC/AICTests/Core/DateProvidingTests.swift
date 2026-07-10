//
//  DateProvidingTests.swift
//  AICTests
//

import XCTest
@testable import AIC

final class DateProvidingTests: XCTestCase {

    func test_systemDateProvider_now_tracksRealClock() {
        let before = Date()
        let now = SystemDateProvider().now
        let after = Date()

        XCTAssertTrue((before...after).contains(now))
    }

    func test_systemDateProvider_now_advances() {
        let provider = SystemDateProvider()

        let first = provider.now
        let second = provider.now

        XCTAssertGreaterThanOrEqual(second, first)
    }
}
