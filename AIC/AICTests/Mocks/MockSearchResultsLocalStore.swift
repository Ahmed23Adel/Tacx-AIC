//
//  MockSearchResultsLocalStore.swift
//  AICTests
//

import Foundation
@testable import AIC

final class MockSearchResultsLocalStore: SearchResultsLocalStoreProtocol {
    // Tracking
    private(set) var fetchedPages: [Int] = []
    private(set) var savedPages: [(pageNumber: Int, artworks: [Artwork])] = []
    private(set) var savedTotalPages: [Int] = []
    private(set) var deletedPages: [Int] = []
    private(set) var deleteAllPagesCallCount = 0

    // Stubbable results
    var stubbedFetchPageResult: Result<CachedSearchPage?, Error> = .success(nil)
    var stubbedTotalPagesResult: Result<Int?, Error> = .success(nil)
    var savePageError: Error?
    var saveTotalPagesError: Error?
    var deleteAllPagesError: Error?

    func fetchPage(_ pageNumber: Int) async throws -> CachedSearchPage? {
        fetchedPages.append(pageNumber)
        return try stubbedFetchPageResult.get()
    }

    func savePage(_ pageNumber: Int, artworks: [Artwork]) async throws {
        if let savePageError { throw savePageError }
        savedPages.append((pageNumber, artworks))
    }

    func deletePage(_ pageNumber: Int) async throws {
        deletedPages.append(pageNumber)
    }

    func fetchTotalPages() async throws -> Int? {
        try stubbedTotalPagesResult.get()
    }

    func saveTotalPages(_ totalPages: Int) async throws {
        if let saveTotalPagesError { throw saveTotalPagesError }
        savedTotalPages.append(totalPages)
    }

    func deleteAllPages() async throws {
        deleteAllPagesCallCount += 1
        if let deleteAllPagesError { throw deleteAllPagesError }
    }
}
