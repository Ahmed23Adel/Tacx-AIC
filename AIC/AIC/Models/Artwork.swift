//
//  Artwork.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

struct Artwork: Identifiable, Decodable {
    let id: Int
    let title: String?
    let imageId: String?
    let dateDisplay: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageId = "image_id"
        case dateDisplay = "date_display"
    }
}
