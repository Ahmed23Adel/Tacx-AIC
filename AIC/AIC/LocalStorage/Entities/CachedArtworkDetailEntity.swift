//
//  CachedArtworkDetailEntity.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData

@Model
final class CachedArtworkDetailEntity {
    @Attribute(.unique) var artworkId: Int
    var title: String?
    var artistDisplay: String?
    var dateDisplay: String?
    var mediumDisplay: String?
    var dimensions: String?
    var placeOfOrigin: String?
    var creditLine: String?
    var imageId: String?
    var shortDescription: String?
    var longDescription: String?
    var insertedAt: Date

    init(
        artworkId: Int,
        title: String?,
        artistDisplay: String?,
        dateDisplay: String?,
        mediumDisplay: String?,
        dimensions: String?,
        placeOfOrigin: String?,
        creditLine: String?,
        imageId: String?,
        shortDescription: String?,
        longDescription: String?,
        insertedAt: Date
    ) {
        self.artworkId = artworkId
        self.title = title
        self.artistDisplay = artistDisplay
        self.dateDisplay = dateDisplay
        self.mediumDisplay = mediumDisplay
        self.dimensions = dimensions
        self.placeOfOrigin = placeOfOrigin
        self.creditLine = creditLine
        self.imageId = imageId
        self.shortDescription = shortDescription
        self.longDescription = longDescription
        self.insertedAt = insertedAt
    }
}

// MARK: - Domain mapping

extension CachedArtworkDetailEntity {
    convenience init(detail: ArtworkDetail, insertedAt: Date) {
        self.init(
            artworkId: detail.id,
            title: detail.title,
            artistDisplay: detail.artistDisplay,
            dateDisplay: detail.dateDisplay,
            mediumDisplay: detail.mediumDisplay,
            dimensions: detail.dimensions,
            placeOfOrigin: detail.placeOfOrigin,
            creditLine: detail.creditLine,
            imageId: detail.imageId,
            shortDescription: detail.shortDescription,
            longDescription: detail.description,
            insertedAt: insertedAt
        )
    }

    func toDomain() -> ArtworkDetail {
        ArtworkDetail(
            id: artworkId,
            title: title,
            artistDisplay: artistDisplay,
            dateDisplay: dateDisplay,
            mediumDisplay: mediumDisplay,
            dimensions: dimensions,
            placeOfOrigin: placeOfOrigin,
            creditLine: creditLine,
            imageId: imageId,
            shortDescription: shortDescription,
            description: longDescription
        )
    }
}
