//
//  ArtworkRepositoryProtocol.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

protocol ArtworkRepositoryProtocol {
    func searchArtworks(page: Int) async throws -> ([Artwork], Pagination)
    func artworkDetail(id: Int) async throws -> ArtworkDetail
}
