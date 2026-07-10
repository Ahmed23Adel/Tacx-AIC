//
//  SearchArtworksEndpoint.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

struct SearchArtworksEndpoint: Endpoint {
    typealias Response = SearchArtworksResponse

    let artistTitle: String
    let page: Int
    var limit: Int = 20

    var path: String { "/artworks/search" }
    var parameters: [String: String] {
        [
            "query[match_phrase][artist_title]": artistTitle,
            "fields": "id,title,image_id,date_display",
            "limit": "\(limit)",
            "page": "\(page)",
        ]
    }
}
