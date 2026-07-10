//
//  LocalStorePersistenceIntegrationTests.swift
//  AICTests
//
//  Integration: exercises the store through the protocol, then verifies the
//  actual database rows with an independent ModelContext — proving schema-level
//  behavior (cascade deletes, no orphans) that the public API can't show.
//

import XCTest
import SwiftData
@testable import AIC

final class LocalStorePersistenceIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var sut: SwiftDataArtworkLocalStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        sut = SwiftDataArtworkLocalStore(
            modelContainer: container,
            dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_750_000_000))
        )
    }

    override func tearDown() {
        sut = nil
        container = nil
        super.tearDown()
    }

    // MARK: - DB row inspection helpers (fresh context = unbiased view of the store)

    private func artworkRowCount() throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<CachedArtworkEntity>())
    }

    private func pageRowCount() throws -> Int {
        try ModelContext(container).fetchCount(FetchDescriptor<CachedSearchPageEntity>())
    }

    // MARK: - Cascade / orphan guarantees

    func test_savePage_replacement_leavesNoOrphanArtworkRows() async throws {
        // Regression guard for the cascade delete rule: without it, every page
        // refresh would strand the previous artworks as unreachable rows.
        let twenty = (1...20).map { Fixtures.artwork(id: $0) }
        try await sut.savePage(1, artworks: twenty)

        let five = (100...104).map { Fixtures.artwork(id: $0) }
        try await sut.savePage(1, artworks: five)

        XCTAssertEqual(try artworkRowCount(), 5, "old page's artwork rows must be cascade-deleted on replacement")
    }

    func test_deletePage_cascadesItsArtworkRows() async throws {
        try await sut.savePage(1, artworks: (1...10).map { Fixtures.artwork(id: $0) })

        try await sut.deletePage(1)

        XCTAssertEqual(try pageRowCount(), 0)
        XCTAssertEqual(try artworkRowCount(), 0, "deleting a page must delete its artwork rows")
    }

    func test_deletePage_cascadeDoesNotTouchOtherPagesRows() async throws {
        try await sut.savePage(1, artworks: (1...10).map { Fixtures.artwork(id: $0) })
        try await sut.savePage(2, artworks: (11...15).map { Fixtures.artwork(id: $0) })

        try await sut.deletePage(1)

        XCTAssertEqual(try artworkRowCount(), 5, "cascade must be scoped to the deleted page")
    }

    func test_sameArtworkOnTwoPages_storesTwoIndependentRows() async throws {
        // Documents the deliberate page-snapshot denormalization: artworkId is
        // NOT globally unique, so overlapping pages own separate rows.
        let shared = Fixtures.artwork(id: 74)

        try await sut.savePage(1, artworks: [shared])
        try await sut.savePage(2, artworks: [shared])

        XCTAssertEqual(try artworkRowCount(), 2)
    }

    // MARK: - Store instances share the container's data

    func test_twoStores_overSameContainer_seeTheSameData() async throws {
        try await sut.savePage(1, artworks: [Fixtures.artwork(id: 1)])

        let secondStore = SwiftDataArtworkLocalStore(modelContainer: container)
        let cached = try await secondStore.fetchPage(1)

        XCTAssertEqual(cached?.artworks.map(\.id), [1], "data must live in the container, not the store instance")
    }

    // MARK: - deleteAllPages: row-level verification

    func test_deleteAllPages_leavesZeroPageArtworkAndMetadataRows() async throws {
        try await sut.savePage(1, artworks: (1...10).map { Fixtures.artwork(id: $0) })
        try await sut.savePage(2, artworks: (11...15).map { Fixtures.artwork(id: $0) })
        try await sut.saveTotalPages(13)

        try await sut.deleteAllPages()

        XCTAssertEqual(try pageRowCount(), 0)
        XCTAssertEqual(try artworkRowCount(), 0, "cascade must clean every page's artwork rows")
        let metadataCount = try ModelContext(container).fetchCount(FetchDescriptor<CachedSearchMetadataEntity>())
        XCTAssertEqual(metadataCount, 0)
    }

    func test_saveTotalPages_repeatedSaves_keepExactlyOneMetadataRow() async throws {
        // Singleton contract at the row level: upsert, never accumulate.
        try await sut.saveTotalPages(13)
        try await sut.saveTotalPages(14)
        try await sut.saveTotalPages(15)

        let metadataCount = try ModelContext(container).fetchCount(FetchDescriptor<CachedSearchMetadataEntity>())
        XCTAssertEqual(metadataCount, 1)
    }

    // MARK: - Real save failure through the public API

    func test_savePage_onReadOnlyContainer_throwsSaveFailed() async throws {
        // A read-only container makes modelContext.save() genuinely fail — a real
        // SwiftData error flowing through the mapper, not a mock. Read-only must
        // load an EXISTING store, so create one on disk first, then reopen it
        // with allowsSave: false.
        let schema = Schema([
            CachedSearchPageEntity.self,
            CachedArtworkEntity.self,
            CachedArtworkDetailEntity.self,
        ])
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "ReadOnlyTest-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        // 1. Create a real store file with a writable container.
        var writable: ModelContainer? = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let seedContext = ModelContext(writable!)
        seedContext.insert(CachedSearchPageEntity(pageNumber: 99, insertedAt: Date(timeIntervalSince1970: 0)))
        try seedContext.save()
        writable = nil

        // 2. Reopen it read-only and drive the store through its public API.
        let readOnlyContainer = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, allowsSave: false)]
        )
        let readOnlyStore = SwiftDataArtworkLocalStore(modelContainer: readOnlyContainer)

        do {
            try await readOnlyStore.savePage(1, artworks: [Fixtures.artwork()])
            XCTFail("Expected LocalStoreError.saveFailed")
        } catch let error as LocalStoreError {
            guard case .saveFailed = error else {
                return XCTFail("Expected .saveFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected LocalStoreError, got \(error)")
        }
    }

    // MARK: - Full page-and-detail flow (mirrors layer 4's future usage)

    func test_fullFlow_savePageAndDetail_fetchBothIndependently() async throws {
        let artwork = Fixtures.artwork(id: 95998)
        let detail = Fixtures.artworkDetail(id: 95998)

        try await sut.savePage(1, artworks: [artwork])
        try await sut.saveDetail(detail)

        let cachedPage = try await sut.fetchPage(1)
        let cachedDetail = try await sut.fetchDetail(id: 95998)

        XCTAssertEqual(cachedPage?.artworks.first?.id, 95998)
        XCTAssertEqual(cachedDetail?.detail.id, 95998)

        // Deleting the page must not delete the artwork's detail — separate tables.
        try await sut.deletePage(1)
        let detailAfter = try await sut.fetchDetail(id: 95998)
        XCTAssertNotNil(detailAfter)
    }
}
