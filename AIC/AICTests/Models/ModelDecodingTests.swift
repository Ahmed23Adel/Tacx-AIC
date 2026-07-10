//
//  ModelDecodingTests.swift
//  AICTests
//
//  Decoding contract for Artwork, ArtworkDetail, Pagination and the
//  response envelopes, verified against real AIC API payload shapes.
//

import XCTest
@testable import AIC

final class ModelDecodingTests: XCTestCase {

    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        decoder = JSONDecoder()
    }

    override func tearDown() {
        decoder = nil
        super.tearDown()
    }

    // MARK: SearchArtworksResponse

    func test_searchResponse_withRealPayload_decodesArtworksAndPagination() throws {
        let response = try decoder.decode(SearchArtworksResponse.self, from: Fixtures.searchJSON)

        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.data[0].id, 95998)
        XCTAssertEqual(response.data[0].title, "Old Man with a Gold Chain")
        XCTAssertEqual(response.data[0].imageId, "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb")
        XCTAssertEqual(response.data[0].dateDisplay, "1631")
        XCTAssertEqual(response.data[1].id, 90536)
    }

    func test_searchResponse_withRealPayload_decodesPaginationSnakeCaseKeys() throws {
        let response = try decoder.decode(SearchArtworksResponse.self, from: Fixtures.searchJSON)

        XCTAssertEqual(response.pagination.total, 247)
        XCTAssertEqual(response.pagination.limit, 20)
        XCTAssertEqual(response.pagination.offset, 0)
        XCTAssertEqual(response.pagination.totalPages, 13)
        XCTAssertEqual(response.pagination.currentPage, 1)
    }

    func test_searchResponse_ignoresUndeclaredKeys() throws {
        // preference, _score, info, config are present in the fixture and must not break decoding
        XCTAssertNoThrow(try decoder.decode(SearchArtworksResponse.self, from: Fixtures.searchJSON))
    }

    // MARK: Artwork

    func test_artwork_withNullOptionals_decodesWithNilFields() throws {
        let artwork = try decoder.decode(Artwork.self, from: Fixtures.artworkAllNullJSON)

        XCTAssertEqual(artwork.id, 42)
        XCTAssertNil(artwork.title)
        XCTAssertNil(artwork.imageId)
        XCTAssertNil(artwork.dateDisplay)
    }

    func test_artwork_withAbsentOptionals_decodesWithNilFields() throws {
        let artwork = try decoder.decode(Artwork.self, from: Fixtures.artworkOnlyIdJSON)

        XCTAssertEqual(artwork.id, 7)
        XCTAssertNil(artwork.title)
        XCTAssertNil(artwork.imageId)
        XCTAssertNil(artwork.dateDisplay)
    }

    func test_artwork_withMissingId_throwsDecodingError() {
        XCTAssertThrowsError(try decoder.decode(Artwork.self, from: Fixtures.artworkMissingIdJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func test_artwork_identifiable_idMatchesDecodedValue() throws {
        let artwork = try decoder.decode(Artwork.self, from: Fixtures.artworkOnlyIdJSON)
        XCTAssertEqual(artwork.id, 7)
    }

    // MARK: ArtworkDetailResponse / ArtworkDetail

    func test_detailResponse_withRealPayload_decodesAllFields() throws {
        let response = try decoder.decode(ArtworkDetailResponse.self, from: Fixtures.detailJSON)
        let detail = response.data

        XCTAssertEqual(detail.id, 95998)
        XCTAssertEqual(detail.title, "Old Man with a Gold Chain")
        XCTAssertEqual(detail.artistDisplay, "Rembrandt van Rijn (Dutch, 1606-1669)")
        XCTAssertEqual(detail.dateDisplay, "1631")
        XCTAssertEqual(detail.mediumDisplay, "Oil on panel")
        XCTAssertEqual(detail.dimensions, "72.3 x 59.9 cm (28 1/2 x 23 5/8 in.)")
        XCTAssertEqual(detail.placeOfOrigin, "Holland")
        XCTAssertEqual(detail.creditLine, "Mr. and Mrs. W. W. Kimball Collection")
        XCTAssertEqual(detail.imageId, "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb")
        XCTAssertEqual(detail.shortDescription, "A character study known as a tronie.")
        XCTAssertEqual(detail.description, "<p>This compelling figure represents a tronie.</p>")
    }

    func test_detailResponse_withAbsentOptionals_decodesWithNilFields() throws {
        let response = try decoder.decode(ArtworkDetailResponse.self, from: Fixtures.detailAllOptionalsAbsentJSON)
        let detail = response.data

        XCTAssertEqual(detail.id, 9)
        XCTAssertNil(detail.title)
        XCTAssertNil(detail.artistDisplay)
        XCTAssertNil(detail.dateDisplay)
        XCTAssertNil(detail.mediumDisplay)
        XCTAssertNil(detail.dimensions)
        XCTAssertNil(detail.placeOfOrigin)
        XCTAssertNil(detail.creditLine)
        XCTAssertNil(detail.imageId)
        XCTAssertNil(detail.shortDescription)
        XCTAssertNil(detail.description)
    }

    func test_detail_withInvalidJSON_throwsDecodingError() {
        XCTAssertThrowsError(try decoder.decode(ArtworkDetailResponse.self, from: Fixtures.notJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}
