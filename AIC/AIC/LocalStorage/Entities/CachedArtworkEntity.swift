//
//  CachedArtworkEntity.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData

@Model
final class CachedArtworkEntity {
    var artworkId: Int
    var title: String?
    var imageId: String?
    var dateDisplay: String?
    var sortIndex: Int

    var page: CachedSearchPageEntity?

    init(artworkId: Int, title: String?, imageId: String?, dateDisplay: String?, sortIndex: Int, page: CachedSearchPageEntity?) {
        self.artworkId = artworkId
        self.title = title
        self.imageId = imageId
        self.dateDisplay = dateDisplay
        self.sortIndex = sortIndex
        self.page = page
    }
}

// MARK: - Domain mapping

extension CachedArtworkEntity {
    convenience init(artwork: Artwork, sortIndex: Int, page: CachedSearchPageEntity?) {
        self.init(
            artworkId: artwork.id,
            title: artwork.title,
            imageId: artwork.imageId,
            dateDisplay: artwork.dateDisplay,
            sortIndex: sortIndex,
            page: page
        )
    }

    func toDomain() -> Artwork {
        Artwork(id: artworkId, title: title, imageId: imageId, dateDisplay: dateDisplay)
    }
}
