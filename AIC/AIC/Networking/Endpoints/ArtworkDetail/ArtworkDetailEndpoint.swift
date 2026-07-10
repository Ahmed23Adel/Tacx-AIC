//
//  ArtworkDetailEndpoint.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

struct ArtworkDetailEndpoint: Endpoint {
    typealias Response = ArtworkDetailResponse

    let id: Int

    var path: String { "/artworks/\(id)" }
    var parameters: [String: String] {
        ["fields": "id,title,artist_display,date_display,medium_display,dimensions,place_of_origin,credit_line,image_id,short_description,description"]
    }
}
