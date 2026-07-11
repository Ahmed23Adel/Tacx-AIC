//
//  PaginationTrackerTests.swift
//  AICTests
//
//  Full decision matrix of the prefetch rule — pure logic, no mocks.
//

import XCTest
@testable import AIC

final class PaginationTrackerTests: XCTestCase {

    private var sut: PaginationTracker!

    override func setUp() {
        super.setUp()
        sut = PaginationTracker(prefetchDistance: 5)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - shouldLoadNextPage: threshold boundary

    func test_shouldLoad_exactlyAtThreshold_returnsTrue() {
        // 20 items, distance 5: index 15 is the first prefetch-triggering row.
        let result = sut.shouldLoadNextPage(visibleIndex: 15, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false)
        XCTAssertTrue(result)
    }

    func test_shouldLoad_oneBeforeThreshold_returnsFalse() {
        let result = sut.shouldLoadNextPage(visibleIndex: 14, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false)
        XCTAssertFalse(result)
    }

    func test_shouldLoad_lastVisibleIndex_returnsTrue() {
        let result = sut.shouldLoadNextPage(visibleIndex: 19, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false)
        XCTAssertTrue(result)
    }

    func test_shouldLoad_firstIndex_returnsFalse() {
        let result = sut.shouldLoadNextPage(visibleIndex: 0, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false)
        XCTAssertFalse(result)
    }

    // MARK: - shouldLoadNextPage: guards

    func test_shouldLoad_whenBusy_returnsFalseEvenAtEnd() {
        let result = sut.shouldLoadNextPage(visibleIndex: 19, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: true)
        XCTAssertFalse(result)
    }

    func test_shouldLoad_withNoItems_returnsFalse() {
        let result = sut.shouldLoadNextPage(visibleIndex: 0, itemCount: 0, currentPage: 0, totalPages: nil, isBusy: false)
        XCTAssertFalse(result)
    }

    func test_shouldLoad_onLastPage_returnsFalse() {
        let result = sut.shouldLoadNextPage(visibleIndex: 19, itemCount: 20, currentPage: 13, totalPages: 13, isBusy: false)
        XCTAssertFalse(result)
    }

    func test_shouldLoad_withUnknownTotalPages_assumesMoreExist() {
        let result = sut.shouldLoadNextPage(visibleIndex: 19, itemCount: 20, currentPage: 1, totalPages: nil, isBusy: false)
        XCTAssertTrue(result)
    }

    // MARK: - prefetchDistance configurations

    func test_shouldLoad_distanceZero_neverTriggers() {
        // itemCount - 0 = itemCount, and the max index is itemCount - 1:
        // distance 0 disables prefetching entirely.
        let tracker = PaginationTracker(prefetchDistance: 0)
        let result = tracker.shouldLoadNextPage(visibleIndex: 19, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false)
        XCTAssertFalse(result)
    }

    func test_shouldLoad_distanceOne_triggersOnlyOnLastRow() {
        let tracker = PaginationTracker(prefetchDistance: 1)
        XCTAssertTrue(tracker.shouldLoadNextPage(visibleIndex: 19, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false))
        XCTAssertFalse(tracker.shouldLoadNextPage(visibleIndex: 18, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false))
    }

    func test_shouldLoad_distanceLargerThanList_triggersOnAnyRow() {
        let tracker = PaginationTracker(prefetchDistance: 999)
        let result = tracker.shouldLoadNextPage(visibleIndex: 0, itemCount: 20, currentPage: 1, totalPages: 13, isBusy: false)
        XCTAssertTrue(result)
    }

    // MARK: - hasMorePages

    func test_hasMorePages_currentBelowTotal_returnsTrue() {
        XCTAssertTrue(sut.hasMorePages(currentPage: 1, totalPages: 13))
    }

    func test_hasMorePages_currentEqualsTotal_returnsFalse() {
        XCTAssertFalse(sut.hasMorePages(currentPage: 13, totalPages: 13))
    }

    func test_hasMorePages_unknownTotal_returnsTrue() {
        XCTAssertTrue(sut.hasMorePages(currentPage: 5, totalPages: nil))
    }

    func test_hasMorePages_nothingLoadedYet_returnsTrue() {
        XCTAssertTrue(sut.hasMorePages(currentPage: 0, totalPages: 13))
    }
}
