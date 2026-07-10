//
//  LiveAPIIntegrationTests.swift
//  AICTests
//
//  End-to-end against the real AIC API: repository -> Alamofire -> network -> decode.
//  These require internet and depend on external data, so they are inherently
//  slower and can fail for reasons outside the code. Set SKIP_LIVE_TESTS=1 in the
//  scheme's test environment variables to exclude them (e.g. on CI).
//

import XCTest
@testable import AIC

final class LiveAPIIntegrationTests: XCTestCase {

    private var repository: ArtworkRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SKIP_LIVE_TESTS"] == "1",
            "Live API tests skipped via SKIP_LIVE_TESTS"
        )
        // force unwrap OK: static, known-valid URL literal
        repository = ArtworkRepository(
            apiRequester: AlamofireAPIRequester(baseURL: URL(string: "https://api.artic.edu/api/v1")!)
        )
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    func test_liveSearch_page1_returnsArtworksWithConsistentPagination() async throws {
        let (artworks, pagination) = try await repository.searchArtworks(page: 1)

        XCTAssertFalse(artworks.isEmpty, "Featured artist search should return artworks")
        XCTAssertLessThanOrEqual(artworks.count, AppConstants.API.pageLimit)
        XCTAssertEqual(pagination.currentPage, 1)
        XCTAssertGreaterThan(pagination.total, 0)
        XCTAssertGreaterThanOrEqual(pagination.totalPages, 1)
    }

    func test_liveSearchThenDetail_firstArtwork_detailIdMatchesSearchResult() async throws {
        let (artworks, _) = try await repository.searchArtworks(page: 1)
        let first = try XCTUnwrap(artworks.first, "Need at least one search result to fetch detail")

        let detail = try await repository.artworkDetail(id: first.id)

        XCTAssertEqual(detail.id, first.id)
        XCTAssertEqual(detail.title, first.title, "Detail title should match the search thumbnail's title")
        XCTAssertNotNil(detail.artistDisplay, "Featured-artist artworks should carry artist_display")
    }
}
