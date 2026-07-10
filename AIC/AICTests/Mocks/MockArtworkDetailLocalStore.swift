//
//  MockArtworkDetailLocalStore.swift
//  AICTests
//

import Foundation
@testable import AIC

final class MockArtworkDetailLocalStore: ArtworkDetailLocalStoreProtocol {
    // Tracking
    private(set) var fetchedIds: [Int] = []
    private(set) var savedDetails: [ArtworkDetail] = []
    private(set) var deletedIds: [Int] = []
    private(set) var deleteAllDetailsCallCount = 0

    // Stubbable results
    var stubbedFetchDetailResult: Result<CachedArtworkDetail?, Error> = .success(nil)
    var saveDetailError: Error?
    var deleteAllDetailsError: Error?

    func fetchDetail(id: Int) async throws -> CachedArtworkDetail? {
        fetchedIds.append(id)
        return try stubbedFetchDetailResult.get()
    }

    func saveDetail(_ detail: ArtworkDetail) async throws {
        if let saveDetailError { throw saveDetailError }
        savedDetails.append(detail)
    }

    func deleteDetail(id: Int) async throws {
        deletedIds.append(id)
    }

    func deleteAllDetails() async throws {
        deleteAllDetailsCallCount += 1
        if let deleteAllDetailsError { throw deleteAllDetailsError }
    }
}
