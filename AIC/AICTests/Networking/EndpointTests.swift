//
//  EndpointTests.swift
//  AICTests
//
//  Endpoints are pure values: assert the request description they build.
//

import XCTest
import Alamofire
@testable import AIC

final class EndpointTests: XCTestCase {

    // MARK: SearchArtworksEndpoint

    func test_searchEndpoint_path_isArtworksSearch() {
        let endpoint = SearchArtworksEndpoint(artistTitle: "Rembrandt van Rijn", page: 1)
        XCTAssertEqual(endpoint.path, "/artworks/search")
    }

    func test_searchEndpoint_method_defaultsToGet() {
        // Covers the Endpoint protocol extension's default implementation
        let endpoint = SearchArtworksEndpoint(artistTitle: "Rembrandt van Rijn", page: 1)
        XCTAssertEqual(endpoint.method, .get)
    }

    func test_searchEndpoint_parameters_containExactMatchPhraseQuery() {
        let endpoint = SearchArtworksEndpoint(artistTitle: "Rembrandt van Rijn", page: 3, limit: 50)

        XCTAssertEqual(endpoint.parameters, [
            "query[match_phrase][artist_title]": "Rembrandt van Rijn",
            "fields": "id,title,image_id,date_display",
            "limit": "50",
            "page": "3",
        ])
    }

    func test_searchEndpoint_limit_defaultsTo20() {
        let endpoint = SearchArtworksEndpoint(artistTitle: "Monet", page: 1)
        XCTAssertEqual(endpoint.parameters["limit"], "20")
    }

    func test_searchEndpoint_artistWithSpaces_storedUnencoded() {
        // Encoding is Alamofire's job at request time; the endpoint must hold the raw value,
        // otherwise it would get double-encoded.
        let endpoint = SearchArtworksEndpoint(artistTitle: "Rembrandt van Rijn", page: 1)
        XCTAssertEqual(endpoint.parameters["query[match_phrase][artist_title]"], "Rembrandt van Rijn")
    }

    // MARK: ArtworkDetailEndpoint

    func test_detailEndpoint_path_interpolatesId() {
        let endpoint = ArtworkDetailEndpoint(id: 95998)
        XCTAssertEqual(endpoint.path, "/artworks/95998")
    }

    func test_detailEndpoint_method_defaultsToGet() {
        let endpoint = ArtworkDetailEndpoint(id: 1)
        XCTAssertEqual(endpoint.method, .get)
    }

    func test_detailEndpoint_parameters_requestAllModelFields() {
        let endpoint = ArtworkDetailEndpoint(id: 1)

        XCTAssertEqual(endpoint.parameters, [
            "fields": "id,title,artist_display,date_display,medium_display,dimensions,place_of_origin,credit_line,image_id,short_description,description"
        ])
    }

    func test_detailEndpoint_fields_staysInSyncWithArtworkDetailModel() throws {
        // Regression guard: every field the endpoint requests must decode into ArtworkDetail,
        // and the model must not expect fields the endpoint doesn't request (dead fields).
        let endpoint = ArtworkDetailEndpoint(id: 1)
        let requested = Set(try XCTUnwrap(endpoint.parameters["fields"]).split(separator: ",").map(String.init))

        let modelKeys: Set<String> = [
            "id", "title", "artist_display", "date_display", "medium_display",
            "dimensions", "place_of_origin", "credit_line", "image_id",
            "short_description", "description",
        ]

        XCTAssertEqual(requested, modelKeys)
    }
}
