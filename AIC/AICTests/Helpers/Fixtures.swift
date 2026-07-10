//
//  Fixtures.swift
//  AICTests
//
//  JSON fixtures captured from real AIC API responses (2026-07-10),
//  trimmed to two items. Model fixtures use default parameters so
//  call sites only name what matters to the test.
//

import Foundation
@testable import AIC

enum Fixtures {

    // MARK: JSON

    /// Real /artworks/search payload shape, including keys we deliberately ignore
    /// (preference, _score, info, config).
    static let searchJSON = Data("""
    {
      "preference": null,
      "pagination": {
        "total": 247,
        "limit": 20,
        "offset": 0,
        "total_pages": 13,
        "current_page": 1
      },
      "data": [
        {
          "_score": 16058.504,
          "id": 95998,
          "title": "Old Man with a Gold Chain",
          "date_display": "1631",
          "image_id": "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb"
        },
        {
          "_score": 12535.995,
          "id": 90536,
          "title": "Seated Female Nude",
          "date_display": "1660/62",
          "image_id": "6fa39eac-ad97-a247-920f-210a370a3f52"
        }
      ],
      "info": { "version": "1.14" },
      "config": { "iiif_url": "https://www.artic.edu/iiif/2" }
    }
    """.utf8)

    /// Real /artworks/{id} payload shape.
    static let detailJSON = Data("""
    {
      "data": {
        "id": 95998,
        "title": "Old Man with a Gold Chain",
        "date_display": "1631",
        "artist_display": "Rembrandt van Rijn (Dutch, 1606-1669)",
        "place_of_origin": "Holland",
        "dimensions": "72.3 x 59.9 cm (28 1/2 x 23 5/8 in.)",
        "medium_display": "Oil on panel",
        "credit_line": "Mr. and Mrs. W. W. Kimball Collection",
        "image_id": "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb",
        "short_description": "A character study known as a tronie.",
        "description": "<p>This compelling figure represents a tronie.</p>"
      },
      "info": { "version": "1.14" }
    }
    """.utf8)

    /// Every optional field null — only id present.
    static let artworkAllNullJSON = Data("""
    { "id": 42, "title": null, "image_id": null, "date_display": null }
    """.utf8)

    /// Optional fields absent entirely (as opposed to null).
    static let artworkOnlyIdJSON = Data("""
    { "id": 7 }
    """.utf8)

    /// Required id missing — must fail to decode.
    static let artworkMissingIdJSON = Data("""
    { "title": "No id here" }
    """.utf8)

    static let detailAllOptionalsAbsentJSON = Data("""
    { "data": { "id": 9 } }
    """.utf8)

    static let notJSON = Data("this is not json".utf8)

    // MARK: Model fixtures

    static func artwork(
        id: Int = 95998,
        title: String? = "Old Man with a Gold Chain",
        imageId: String? = "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb",
        dateDisplay: String? = "1631"
    ) -> Artwork {
        Artwork(id: id, title: title, imageId: imageId, dateDisplay: dateDisplay)
    }

    static func pagination(
        total: Int = 247,
        limit: Int = 20,
        offset: Int = 0,
        totalPages: Int = 13,
        currentPage: Int = 1
    ) -> Pagination {
        Pagination(total: total, limit: limit, offset: offset, totalPages: totalPages, currentPage: currentPage)
    }

    static func artworkDetail(
        id: Int = 95998,
        title: String? = "Old Man with a Gold Chain"
    ) -> ArtworkDetail {
        ArtworkDetail(
            id: id,
            title: title,
            artistDisplay: "Rembrandt van Rijn (Dutch, 1606-1669)",
            dateDisplay: "1631",
            mediumDisplay: "Oil on panel",
            dimensions: "72.3 x 59.9 cm",
            placeOfOrigin: "Holland",
            creditLine: "Mr. and Mrs. W. W. Kimball Collection",
            imageId: "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb",
            shortDescription: "A character study.",
            description: "<p>A tronie.</p>"
        )
    }

    static func searchResponse(
        artworks: [Artwork]? = nil,
        pagination: Pagination? = nil
    ) -> SearchArtworksResponse {
        SearchArtworksResponse(
            pagination: pagination ?? Self.pagination(),
            data: artworks ?? [Self.artwork()]
        )
    }

    static func detailResponse(detail: ArtworkDetail? = nil) -> ArtworkDetailResponse {
        ArtworkDetailResponse(data: detail ?? Self.artworkDetail())
    }
}
