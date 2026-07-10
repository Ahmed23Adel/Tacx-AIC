//
//  SearchArtworksResponse.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

struct SearchArtworksResponse: Decodable {
    let pagination: Pagination
    let data: [Artwork]
}
