//
//  CachedSearchPageEntity.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData

/// One row per cached search page: links a page number to the moment it was
/// stored, so the cache-policy layer can decide staleness without this layer
/// knowing any TTL.
@Model
final class CachedSearchPageEntity {
    @Attribute(.unique) var pageNumber: Int
    var insertedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CachedArtworkEntity.page)
    var artworks: [CachedArtworkEntity]

    init(pageNumber: Int, insertedAt: Date, artworks: [CachedArtworkEntity] = []) {
        self.pageNumber = pageNumber
        self.insertedAt = insertedAt
        self.artworks = artworks
    }
}
