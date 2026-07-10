//
//  ArtworkRepository.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

final class ArtworkRepository: ArtworkRepositoryProtocol {
    private let apiRequester: APIRequester

    init(apiRequester: APIRequester) {
        self.apiRequester = apiRequester
    }

    func searchArtworks(page: Int) async throws -> ([Artwork], Pagination) {
        let response = try await apiRequester.send(
            SearchArtworksEndpoint(
                artistTitle: AppConstants.Artist.featured,
                page: page,
                limit: AppConstants.API.pageLimit
            )
        )
        return (response.data, response.pagination)
    }

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        try await apiRequester.send(ArtworkDetailEndpoint(id: id)).data
    }
}
