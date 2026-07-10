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

    func test_make_registersAllThreeEntityTypes() throws {
        // Regression guard: an entity missing from the factory's Schema would
        // crash at first insert in production. Inserting one of each proves the
        // schema is complete.
        let container = try ArtworkCacheContainerFactory.make(inMemoryOnly: true)
        let context = ModelContext(container)

        let page = CachedSearchPageEntity(pageNumber: 1, insertedAt: Date(timeIntervalSince1970: 0))
        context.insert(page)
        context.insert(CachedArtworkEntity(artwork: Fixtures.artwork(), sortIndex: 0, page: page))
        context.insert(CachedArtworkDetailEntity(detail: Fixtures.artworkDetail(), insertedAt: Date(timeIntervalSince1970: 0)))

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
}
