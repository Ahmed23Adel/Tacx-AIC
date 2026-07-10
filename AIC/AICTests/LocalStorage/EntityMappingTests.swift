//
//  EntityMappingTests.swift
//  AICTests
//
//  The entity <-> domain mapping is the layer's border: these tests pin every
//  field crossing it, in both directions.
//

import XCTest
@testable import AIC

final class EntityMappingTests: XCTestCase {

    // MARK: - CachedArtworkEntity

    func test_artworkEntity_initFromDomain_mapsAllFields() {
        let artwork = Fixtures.artwork(id: 95998)

        let entity = CachedArtworkEntity(artwork: artwork, sortIndex: 3, page: nil)

        XCTAssertEqual(entity.artworkId, 95998)
        XCTAssertEqual(entity.title, artwork.title)
        XCTAssertEqual(entity.imageId, artwork.imageId)
        XCTAssertEqual(entity.dateDisplay, artwork.dateDisplay)
        XCTAssertEqual(entity.sortIndex, 3)
        XCTAssertNil(entity.page)
    }

    func test_artworkEntity_toDomain_roundtripsAllFields() {
        let original = Fixtures.artwork(id: 74)
        let entity = CachedArtworkEntity(artwork: original, sortIndex: 0, page: nil)

        let roundtripped = entity.toDomain()

        XCTAssertEqual(roundtripped.id, original.id)
        XCTAssertEqual(roundtripped.title, original.title)
        XCTAssertEqual(roundtripped.imageId, original.imageId)
        XCTAssertEqual(roundtripped.dateDisplay, original.dateDisplay)
    }

    func test_artworkEntity_withNilOptionals_roundtripsNils() {
        let sparse = Fixtures.artwork(id: 7, title: nil, imageId: nil, dateDisplay: nil)
        let entity = CachedArtworkEntity(artwork: sparse, sortIndex: 0, page: nil)

        let roundtripped = entity.toDomain()

        XCTAssertEqual(roundtripped.id, 7)
        XCTAssertNil(roundtripped.title)
        XCTAssertNil(roundtripped.imageId)
        XCTAssertNil(roundtripped.dateDisplay)
    }

    // MARK: - CachedArtworkDetailEntity

    func test_detailEntity_initFromDomain_mapsDescriptionToLongDescription() {
        let detail = Fixtures.artworkDetail(id: 1)

        let entity = CachedArtworkDetailEntity(detail: detail, insertedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(entity.longDescription, detail.description)
        XCTAssertEqual(entity.shortDescription, detail.shortDescription)
    }

    func test_detailEntity_toDomain_roundtripsAllFields() {
        let original = Fixtures.artworkDetail(id: 95998)
        let entity = CachedArtworkDetailEntity(detail: original, insertedAt: Date(timeIntervalSince1970: 0))

        let roundtripped = entity.toDomain()

        XCTAssertEqual(roundtripped.id, original.id)
        XCTAssertEqual(roundtripped.title, original.title)
        XCTAssertEqual(roundtripped.artistDisplay, original.artistDisplay)
        XCTAssertEqual(roundtripped.dateDisplay, original.dateDisplay)
        XCTAssertEqual(roundtripped.mediumDisplay, original.mediumDisplay)
        XCTAssertEqual(roundtripped.dimensions, original.dimensions)
        XCTAssertEqual(roundtripped.placeOfOrigin, original.placeOfOrigin)
        XCTAssertEqual(roundtripped.creditLine, original.creditLine)
        XCTAssertEqual(roundtripped.imageId, original.imageId)
        XCTAssertEqual(roundtripped.shortDescription, original.shortDescription)
        XCTAssertEqual(roundtripped.description, original.description)
    }

    func test_detailEntity_storesInsertedAtVerbatim() {
        let stamp = Date(timeIntervalSince1970: 1_234_567)

        let entity = CachedArtworkDetailEntity(detail: Fixtures.artworkDetail(), insertedAt: stamp)

        XCTAssertEqual(entity.insertedAt, stamp)
    }
}
