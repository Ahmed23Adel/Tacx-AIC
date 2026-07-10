//
//  CachedSearchPage.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

/// What the local store hands upward for a cached page: the artworks plus the
/// moment they were stored. The cache-policy layer compares insertedAt against
/// its TTL; this layer takes no position on freshness.
struct CachedSearchPage {
    let pageNumber: Int
    let artworks: [Artwork]
    let insertedAt: Date
}
