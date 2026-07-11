//
//  ArtworkImageURLTests.swift
//  AICTests
//

import XCTest
@testable import AIC

final class ArtworkImageURLTests: XCTestCase {

    private let imageId = "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb"

    func test_thumbnail_buildsIIIFURLAt200() {
        let url = ArtworkImageURL.thumbnail(imageId: imageId)
        XCTAssertEqual(
            url?.absoluteString,
            "https://www.artic.edu/iiif/2/\(imageId)/full/200,/0/default.jpg"
        )
    }

    func test_full_buildsIIIFURLAt843() {
        let url = ArtworkImageURL.full(imageId: imageId)
        XCTAssertEqual(
            url?.absoluteString,
            "https://www.artic.edu/iiif/2/\(imageId)/full/843,/0/default.jpg"
        )
    }

    func test_thumbnail_withNilImageId_returnsNil() {
        XCTAssertNil(ArtworkImageURL.thumbnail(imageId: nil))
    }

    func test_full_withNilImageId_returnsNil() {
        XCTAssertNil(ArtworkImageURL.full(imageId: nil))
    }

    func test_thumbnail_withEmptyImageId_returnsNil() {
        XCTAssertNil(ArtworkImageURL.thumbnail(imageId: ""))
    }
}
