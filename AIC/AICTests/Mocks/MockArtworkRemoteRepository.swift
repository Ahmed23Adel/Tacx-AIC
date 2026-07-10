//
//  MockArtworkRemoteRepository.swift
//  AICTests
//

import Foundation
@testable import AIC

final class MockArtworkRemoteRepository: ArtworkRepositoryProtocol {
    // Tracking
    private(set) var searchedPages: [Int] = []
    private(set) var requestedDetailIds: [Int] = []

    // Stubbable results
    var stubbedSearchResult: Result<([Artwork], Pagination), Error> = .failure(MockError.notStubbed)
    var stubbedDetailResult: Result<ArtworkDetail, Error> = .failure(MockError.notStubbed)

    func searchArtworks(page: Int) async throws -> ([Artwork], Pagination) {
        searchedPages.append(page)
        return try stubbedSearchResult.get()
    }

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        requestedDetailIds.append(id)
        return try stubbedDetailResult.get()
    }
}
