//
//  ArtworkImageURL.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation

/// Builds IIIF image URLs from an artwork's image_id — the one place that
/// knows the AIC image server's URL format. Widths follow the API docs'
/// recommended sizes.
enum ArtworkImageURL {
    static func thumbnail(imageId: String?) -> URL? {
        url(imageId: imageId, width: 200)
    }

    static func full(imageId: String?) -> URL? {
        url(imageId: imageId, width: 843)
    }

    private static func url(imageId: String?, width: Int) -> URL? {
        guard let imageId, !imageId.isEmpty else { return nil }
        return URL(string: "\(AppConstants.API.iiifImageBaseURL)/\(imageId)/full/\(width),/0/default.jpg")
    }
}
