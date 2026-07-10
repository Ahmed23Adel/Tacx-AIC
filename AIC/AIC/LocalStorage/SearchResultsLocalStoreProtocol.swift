//
//  SearchResultsLocalStoreProtocol.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

protocol SearchResultsLocalStoreProtocol: Sendable {
    /// Returns the cached page, or nil when that page was never stored.
    func fetchPage(_ pageNumber: Int) async throws -> CachedSearchPage?

    /// Stores a page's artworks, replacing any previous cache for that page
    /// and stamping it with the current time.
    func savePage(_ pageNumber: Int, artworks: [Artwork]) async throws

    /// Removes a cached page if present.
    func deletePage(_ pageNumber: Int) async throws

    /// Returns the total number of pages in the result set, or nil when no
    /// search metadata has ever been stored.
    func fetchTotalPages() async throws -> Int?

    /// Stores the total page count for the result set (singleton — overwrites
    /// any previous value).
    func saveTotalPages(_ totalPages: Int) async throws

    /// Removes all cached pages, their artworks, and the search metadata.
    func deleteAllPages() async throws
}
