//
//  ArtworkFull.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

struct ArtworkFull: Identifiable, Decodable {
    let id: Int
    let title: String?
    let artistDisplay: String?
    let dateDisplay: String?
    let mediumDisplay: String?
    let dimensions: String?
    let placeOfOrigin: String?
    let creditLine: String?
    let imageId: String?
    let shortDescription: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artistDisplay = "artist_display"
        case dateDisplay = "date_display"
        case mediumDisplay = "medium_display"
        case dimensions
        case placeOfOrigin = "place_of_origin"
        case creditLine = "credit_line"
        case imageId = "image_id"
        case shortDescription = "short_description"
        case description
    }
}
