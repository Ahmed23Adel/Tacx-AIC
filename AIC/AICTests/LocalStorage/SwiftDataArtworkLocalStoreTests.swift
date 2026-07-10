//
//  SwiftDataArtworkLocalStoreTests.swift
//  AICTests
//
//  Unit tests for the SwiftData store: in-memory container (isolated, no disk),
//  frozen clock (deterministic timestamps).
//
//  COVERAGE NOTE: the fetchFirst/persist catch branches map SwiftData failures
//  to LocalStoreError, but an in-memory store cannot be made to fail those calls
//  deterministically. Mocking ModelContext to fake failures would test the mock,
//  not the store — accepted gap, mirrored from the layer design review.
//

import XCTest
import SwiftData
@testable import AIC

final class SwiftDataArtworkLocalStoreTests: XCTestCase {

    private static let frozenNow = Date(timeIntervalSince1970: 1_750_000_000)

    private var container: ModelContainer!
    private var sut: SwiftDataArtworkLocalStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        sut = SwiftDataArtworkLocalStore(
            modelContainer: container,
            dateProvider: FixedDateProvider(now: Self.frozenNow)
        )
    }

    override func tearDown() {
        sut = nil
        container = nil
        super.tearDown()
    }

    // MARK: - fetchPage

    func test_fetchPage_whenNeverSaved_returnsNil() async throws {
        let cached = try await sut.fetchPage(1)
        XCTAssertNil(cached)
    }

    func test_savePage_thenFetchPage_roundtripsArtworkFields() async throws {
        let artwork = Fixtures.artwork(id: 95998)

        try await sut.savePage(1, artworks: [artwork])
        let cached = try await sut.fetchPage(1)

        let fetched = try XCTUnwrap(cached?.artworks.first)
        XCTAssertEqual(fetched.id, artwork.id)
        XCTAssertEqual(fetched.title, artwork.title)
        XCTAssertEqual(fetched.imageId, artwork.imageId)
        XCTAssertEqual(fetched.dateDisplay, artwork.dateDisplay)
    }

    func test_savePage_stampsInsertedAtFromInjectedClock() async throws {
        try await sut.savePage(1, artworks: [Fixtures.artwork()])

        let cached = try await sut.fetchPage(1)

        XCTAssertEqual(cached?.insertedAt, Self.frozenNow)
    }

    func test_fetchPage_returnsPageNumberItWasSavedUnder() async throws {
        try await sut.savePage(7, artworks: [Fixtures.artwork()])

        let cached = try await sut.fetchPage(7)

        XCTAssertEqual(cached?.pageNumber, 7)
    }

    func test_fetchPage_preservesAPIResultOrder() async throws {
        // Ids deliberately NOT in ascending order: order must come from position,
        // not from any property of the artwork itself.
        let ordered = [
            Fixtures.artwork(id: 95998),
            Fixtures.artwork(id: 74),
            Fixtures.artwork(id: 181616),
            Fixtures.artwork(id: 12909),
        ]

        try await sut.savePage(1, artworks: ordered)
        let cached = try await sut.fetchPage(1)

        XCTAssertEqual(cached?.artworks.map(\.id), [95998, 74, 181616, 12909])
    }

    func test_savePage_withEmptyArtworks_persistsEmptyPageNotNil() async throws {
        // Documents behavior for layer 4: an empty cached page is distinguishable
        // from "never cached" (which returns nil).
        try await sut.savePage(1, artworks: [])

        let cached = try await sut.fetchPage(1)

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.artworks.count, 0)
    }

    // MARK: - savePage replacement semantics

    func test_savePage_samePageAgain_replacesContents() async throws {
        try await sut.savePage(1, artworks: [Fixtures.artwork(id: 1), Fixtures.artwork(id: 2)])

        try await sut.savePage(1, artworks: [Fixtures.artwork(id: 3)])
        let cached = try await sut.fetchPage(1)

        XCTAssertEqual(cached?.artworks.map(\.id), [3])
    }

    func test_savePage_samePageAgain_refreshesInsertedAt() async throws {
        let later = Self.frozenNow.addingTimeInterval(300)
        try await sut.savePage(1, artworks: [Fixtures.artwork()])

        // A second store over the SAME container but a later clock — data is
        // shared through the container, the clock is per-store.
        let laterStore = SwiftDataArtworkLocalStore(
            modelContainer: container,
            dateProvider: FixedDateProvider(now: later)
        )
        try await laterStore.savePage(1, artworks: [Fixtures.artwork()])

        let cached = try await sut.fetchPage(1)
        XCTAssertEqual(cached?.insertedAt, later)
    }

    func test_savePage_differentPages_areIndependent() async throws {
        try await sut.savePage(1, artworks: [Fixtures.artwork(id: 1)])
        try await sut.savePage(2, artworks: [Fixtures.artwork(id: 2)])

        let page1 = try await sut.fetchPage(1)
        let page2 = try await sut.fetchPage(2)

        XCTAssertEqual(page1?.artworks.map(\.id), [1])
        XCTAssertEqual(page2?.artworks.map(\.id), [2])
    }

    func test_savePage_sameArtworkOnTwoPages_bothPagesKeepIt() async throws {
        // Regression guard for the deliberate non-unique artworkId design:
        // an artwork near a page boundary can legitimately appear on two pages.
        let shared = Fixtures.artwork(id: 74)

        try await sut.savePage(1, artworks: [shared, Fixtures.artwork(id: 1)])
        try await sut.savePage(2, artworks: [shared, Fixtures.artwork(id: 2)])

        let page1 = try await sut.fetchPage(1)
        let page2 = try await sut.fetchPage(2)

        XCTAssertEqual(page1?.artworks.map(\.id), [74, 1])
        XCTAssertEqual(page2?.artworks.map(\.id), [74, 2])
    }

    // MARK: - deletePage

    func test_deletePage_removesCachedPage() async throws {
        try await sut.savePage(1, artworks: [Fixtures.artwork()])

        try await sut.deletePage(1)

        let cached = try await sut.fetchPage(1)
        XCTAssertNil(cached)
    }

    func test_deletePage_whenPageAbsent_doesNotThrow() async throws {
        try await sut.deletePage(99)
    }

    func test_deletePage_leavesOtherPagesIntact() async throws {
        try await sut.savePage(1, artworks: [Fixtures.artwork(id: 1)])
        try await sut.savePage(2, artworks: [Fixtures.artwork(id: 2)])

        try await sut.deletePage(1)

        let page2 = try await sut.fetchPage(2)
        XCTAssertEqual(page2?.artworks.map(\.id), [2])
    }

    // MARK: - fetchDetail / saveDetail

    func test_fetchDetail_whenNeverSaved_returnsNil() async throws {
        let cached = try await sut.fetchDetail(id: 95998)
        XCTAssertNil(cached)
    }

    func test_saveDetail_thenFetchDetail_roundtripsAllFields() async throws {
        let detail = Fixtures.artworkDetail(id: 95998)

        try await sut.saveDetail(detail)
        let cached = try await sut.fetchDetail(id: 95998)

        let fetched = try XCTUnwrap(cached?.detail)
        XCTAssertEqual(fetched.id, detail.id)
        XCTAssertEqual(fetched.title, detail.title)
        XCTAssertEqual(fetched.artistDisplay, detail.artistDisplay)
        XCTAssertEqual(fetched.dateDisplay, detail.dateDisplay)
        XCTAssertEqual(fetched.mediumDisplay, detail.mediumDisplay)
        XCTAssertEqual(fetched.dimensions, detail.dimensions)
        XCTAssertEqual(fetched.placeOfOrigin, detail.placeOfOrigin)
        XCTAssertEqual(fetched.creditLine, detail.creditLine)
        XCTAssertEqual(fetched.imageId, detail.imageId)
        XCTAssertEqual(fetched.shortDescription, detail.shortDescription)
        XCTAssertEqual(fetched.description, detail.description)
    }

    func test_saveDetail_withAllNilOptionals_roundtripsNils() async throws {
        let sparse = Fixtures.artworkDetailAllNil(id: 9)

        try await sut.saveDetail(sparse)
        let cached = try await sut.fetchDetail(id: 9)

        let fetched = try XCTUnwrap(cached?.detail)
        XCTAssertEqual(fetched.id, 9)
        XCTAssertNil(fetched.title)
        XCTAssertNil(fetched.artistDisplay)
        XCTAssertNil(fetched.description)
    }

    func test_saveDetail_stampsInsertedAtFromInjectedClock() async throws {
        try await sut.saveDetail(Fixtures.artworkDetail())

        let cached = try await sut.fetchDetail(id: 95998)

        XCTAssertEqual(cached?.insertedAt, Self.frozenNow)
    }

    func test_saveDetail_existingId_replacesPreviousDetail() async throws {
        try await sut.saveDetail(Fixtures.artworkDetail(id: 1, title: "Old title"))

        try await sut.saveDetail(Fixtures.artworkDetail(id: 1, title: "New title"))
        let cached = try await sut.fetchDetail(id: 1)

        XCTAssertEqual(cached?.detail.title, "New title")
    }

    func test_saveDetail_differentIds_areIndependent() async throws {
        try await sut.saveDetail(Fixtures.artworkDetail(id: 1, title: "First"))
        try await sut.saveDetail(Fixtures.artworkDetail(id: 2, title: "Second"))

        let first = try await sut.fetchDetail(id: 1)
        let second = try await sut.fetchDetail(id: 2)

        XCTAssertEqual(first?.detail.title, "First")
        XCTAssertEqual(second?.detail.title, "Second")
    }

    // MARK: - deleteDetail

    func test_deleteDetail_removesCachedDetail() async throws {
        try await sut.saveDetail(Fixtures.artworkDetail(id: 1))

        try await sut.deleteDetail(id: 1)

        let cached = try await sut.fetchDetail(id: 1)
        XCTAssertNil(cached)
    }

    func test_deleteDetail_whenAbsent_doesNotThrow() async throws {
        try await sut.deleteDetail(id: 99)
    }

    // MARK: - Concurrency

    func test_concurrentSaves_allPagesPersist() async throws {
        // The actor must serialize concurrent saves without losing any.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for page in 1...20 {
                group.addTask { [sut] in
                    try await sut!.savePage(page, artworks: [Fixtures.artwork(id: page)])
                }
            }
            try await group.waitForAll()
        }

        for page in 1...20 {
            let cached = try await sut.fetchPage(page)
            XCTAssertEqual(cached?.artworks.map(\.id), [page], "page \(page) missing or wrong")
        }
    }

    // MARK: - Memory

    func test_store_deallocates_noMemoryLeak() throws {
        var store: SwiftDataArtworkLocalStore? = SwiftDataArtworkLocalStore(
            modelContainer: try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        )
        weak var weakReference = store

        store = nil

        XCTAssertNil(weakReference, "Potential memory leak: SwiftDataArtworkLocalStore not deallocated")
    }
}
