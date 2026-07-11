//
//  CoordinatorTests.swift
//  AICTests
//
//  Navigation logic pinned with exact-route assertions — the reason the
//  path is a typed [AppRoute] instead of an opaque NavigationPath.
//

import XCTest
@testable import AIC

final class CoordinatorTests: XCTestCase {

    private var sut: Coordinator!

    override func setUp() {
        super.setUp()
        sut = Coordinator()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_init_startsWithEmptyPath() {
        XCTAssertTrue(sut.path.isEmpty)
    }

    // MARK: - goToArtworkDetail

    func test_goToArtworkDetail_pushesRouteWithExactId() {
        sut.goToArtworkDetail(id: 95998)

        XCTAssertEqual(sut.path, [.artworkDetail(id: 95998)])
    }

    func test_goToArtworkDetail_repeatedly_stacksRoutesInOrder() {
        sut.goToArtworkDetail(id: 1)
        sut.goToArtworkDetail(id: 2)

        XCTAssertEqual(sut.path, [.artworkDetail(id: 1), .artworkDetail(id: 2)])
    }

    // MARK: - goBack

    func test_goBack_removesOnlyTheLastRoute() {
        sut.goToArtworkDetail(id: 1)
        sut.goToArtworkDetail(id: 2)

        sut.goBack()

        XCTAssertEqual(sut.path, [.artworkDetail(id: 1)])
    }

    func test_goBack_onEmptyPath_doesNotCrash() {
        sut.goBack()

        XCTAssertTrue(sut.path.isEmpty)
    }

    // MARK: - popToRoot

    func test_popToRoot_clearsEntirePath() {
        sut.goToArtworkDetail(id: 1)
        sut.goToArtworkDetail(id: 2)
        sut.goToArtworkDetail(id: 3)

        sut.popToRoot()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_popToRoot_onEmptyPath_doesNotCrash() {
        sut.popToRoot()

        XCTAssertTrue(sut.path.isEmpty)
    }

    // MARK: - Memory

    func test_coordinator_deallocates_noMemoryLeak() {
        var coordinator: Coordinator? = Coordinator()
        weak var weakReference = coordinator

        coordinator = nil

        XCTAssertNil(weakReference, "Potential memory leak: Coordinator not deallocated")
    }
}
