//
//  ArtworkCacheContainerFactoryTests.swift
//  AICTests
//

import XCTest
import SwiftData
@testable import AIC

final class ArtworkCacheContainerFactoryTests: XCTestCase {

    func test_make_inMemory_succeeds() {
        XCTAssertNoThrow(try ArtworkCacheContainerFactory.make(inMemoryOnly: true))
    }

    func test_make_registersAllEntityTypes() throws {
        // Regression guard: an entity missing from the factory's Schema would
        // crash at first insert in production. Inserting one of each proves the
        // schema is complete.
        let container = try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        let context = ModelContext(container)

        let page = CachedSearchPageEntity(pageNumber: 1, insertedAt: Date(timeIntervalSince1970: 0))
        context.insert(page)
        context.insert(CachedArtworkEntity(artwork: Fixtures.artwork(), sortIndex: 0, page: page))
        context.insert(CachedArtworkDetailEntity(detail: Fixtures.artworkDetail(), insertedAt: Date(timeIntervalSince1970: 0)))
        context.insert(CachedSearchMetadataEntity(totalPages: 13))

        XCTAssertNoThrow(try context.save())
    }

    func test_make_producesIsolatedContainers() throws {
        // Two in-memory containers must not share data — this is what guarantees
        // test isolation for every other suite in this folder.
        let containerA = try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        let containerB = try ArtworkCacheContainerFactory.make(inMemoryOnly: true)

        let contextA = ModelContext(containerA)
        contextA.insert(CachedSearchPageEntity(pageNumber: 1, insertedAt: Date(timeIntervalSince1970: 0)))
        try contextA.save()

        let contextB = ModelContext(containerB)
        let pagesInB = try contextB.fetch(FetchDescriptor<CachedSearchPageEntity>())
        XCTAssertTrue(pagesInB.isEmpty)
    }

    // MARK: - resilientContainer recovery policy

    private struct MakeError: Error {}
    private let anyURL = URL(fileURLWithPath: "/tmp/aic-test-store")

    /// Builds an injected `make` that throws for the first `failures` calls,
    /// then succeeds (returns a real in-memory container), recording each call.
    private func makeSpy(failuresBeforeSuccess: Int) -> (make: (Bool, URL) throws -> ModelContainer, calls: () -> [Bool]) {
        var recorded: [Bool] = []
        var remainingFailures = failuresBeforeSuccess
        let make: (Bool, URL) throws -> ModelContainer = { inMemory, _ in
            recorded.append(inMemory)
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw MakeError()
            }
            return try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        }
        return (make, { recorded })
    }

    func test_resilient_diskSucceedsFirstTry_returnsWithoutWipe() {
        let spy = makeSpy(failuresBeforeSuccess: 0)
        var removedURLs: [URL] = []

        _ = ArtworkCacheContainerFactory.resilientContainer(
            make: spy.make,
            storeURL: anyURL,
            removeItem: { removedURLs.append($0) }
        )

        XCTAssertEqual(spy.calls(), [false], "one disk attempt, no in-memory")
        XCTAssertTrue(removedURLs.isEmpty, "a healthy store must not be wiped")
    }

    func test_resilient_diskCorrupt_wipesAndRetriesDisk() {
        let spy = makeSpy(failuresBeforeSuccess: 1) // first disk fails, retry succeeds
        var removedURLs: [URL] = []

        _ = ArtworkCacheContainerFactory.resilientContainer(
            make: spy.make,
            storeURL: anyURL,
            removeItem: { removedURLs.append($0) }
        )

        XCTAssertEqual(spy.calls(), [false, false], "disk, then disk again after wipe")
        XCTAssertEqual(removedURLs, [anyURL], "corrupt store must be wiped once")
    }

    func test_resilient_diskUnusable_fallsBackToInMemory() {
        let spy = makeSpy(failuresBeforeSuccess: 2) // both disk attempts fail
        var removedURLs: [URL] = []

        _ = ArtworkCacheContainerFactory.resilientContainer(
            make: spy.make,
            storeURL: anyURL,
            removeItem: { removedURLs.append($0) }
        )

        XCTAssertEqual(spy.calls(), [false, false, true], "two disk attempts, then in-memory")
        XCTAssertEqual(removedURLs, [anyURL])
    }

    func test_makeResilient_returnsAWorkingContainer() {
        // Integration: the real entry point yields a usable container.
        let container = ArtworkCacheContainerFactory.makeResilient()
        XCTAssertNoThrow(try ModelContext(container).save())
    }

    func test_removeStore_missingFile_doesNotThrow() {
        // The wipe step used by makeResilient: deleting an absent store is a
        // silent no-op (try? swallows the error).
        let absent = URL(fileURLWithPath: "/tmp/aic-nonexistent-\(UUID().uuidString).store")
        ArtworkCacheContainerFactory.removeStore(at: absent)
    }

    func test_makeResilient_withCorruptStore_wipesAndRecovers() throws {
        // End-to-end recovery through the REAL makeResilient: plant a garbage
        // file where the store lives so the first open fails, exercising the
        // wipe-then-retry path (Layer 2) and the real removeStore wiring.
        let url = ArtworkCacheContainerFactory.defaultStoreURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("this is not a valid SwiftData store".utf8).write(to: url)
        defer { ArtworkCacheContainerFactory.removeStore(at: url) }

        let container = ArtworkCacheContainerFactory.makeResilient()

        XCTAssertNoThrow(try ModelContext(container).save(), "must recover to a working store")
    }
}
