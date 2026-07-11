//
//  MockCachedArtworkRepository.swift
//  AICTests
//

import Foundation
@testable import AIC

final class MockCachedArtworkRepository: CachedArtworkRepositoryProtocol {
    // Tracking
    private(set) var searchedPages: [Int] = []
    private(set) var requestedDetailIds: [Int] = []
    private(set) var clearCacheCallCount = 0

    // Stubbable results, per page number
    var stubbedPages: [Int: Result<ArtworkPage, Error>] = [:]
    var stubbedDetailResult: Result<ArtworkDetail, Error> = .failure(MockError.notStubbed)
    var stubbedTotalPages: Int?
    var clearCacheError: Error?

    // Optional suspension gate: when armed, the next searchArtworks call
    // suspends until resumeSuspendedSearch() — for asserting in-flight state.
    var suspendNextSearch = false
    private var suspendedSearch: CheckedContinuation<Void, Never>?

    func searchArtworks(page: Int) async throws -> ArtworkPage {
        searchedPages.append(page)
        if suspendNextSearch {
            suspendNextSearch = false
            await withCheckedContinuation { suspendedSearch = $0 }
        }
        guard let result = stubbedPages[page] else { throw MockError.notStubbed }
        return try result.get()
    }

    func resumeSuspendedSearch() {
        suspendedSearch?.resume()
        suspendedSearch = nil
    }

    // Optional suspension gate for the detail path, mirroring the search gate.
    var suspendNextDetail = false
    private var suspendedDetail: CheckedContinuation<Void, Never>?

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        requestedDetailIds.append(id)
        if suspendNextDetail {
            suspendNextDetail = false
            await withCheckedContinuation { suspendedDetail = $0 }
        }
        return try stubbedDetailResult.get()
    }

    func resumeSuspendedDetail() {
        suspendedDetail?.resume()
        suspendedDetail = nil
    }

    private(set) var refreshedDetailIds: [Int] = []
    var stubbedRefreshDetailResult: Result<ArtworkDetail, Error> = .failure(MockError.notStubbed)

    func refreshArtworkDetail(id: Int) async throws -> ArtworkDetail {
        refreshedDetailIds.append(id)
        return try stubbedRefreshDetailResult.get()
    }

    func totalPages() async -> Int? {
        stubbedTotalPages
    }

    func clearCache() async throws {
        clearCacheCallCount += 1
        if let clearCacheError { throw clearCacheError }
    }
}
