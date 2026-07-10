//
//  Pagination.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

struct Pagination: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let totalPages: Int
    let currentPage: Int

    enum CodingKeys: String, CodingKey {
        case total
        case limit
        case offset
        case totalPages = "total_pages"
        case currentPage = "current_page"
    }
}
