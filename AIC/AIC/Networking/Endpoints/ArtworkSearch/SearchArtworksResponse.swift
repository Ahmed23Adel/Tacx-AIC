//
//  SearchArtworksResponse.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

// The AIC API wraps every payload in { "data": ... }.
struct SearchArtworksResponse: Decodable {
    let pagination: Pagination
    let data: [Artwork]
}
