//
//  CachedArtworkRepositoryProtocol.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

/// The cache-policy layer: the single data entry point for ViewModels.
/// Serves from local storage while entries are fresh, otherwise downloads,
/// caches, and returns. When the device is offline, requests park until
/// connectivity returns (see NetworkMonitorProtocol).
protocol CachedArtworkRepositoryProtocol {
    /// Returns the requested search page, from cache when fresh.
    func searchArtworks(page: Int) async throws -> ArtworkPage

    /// Returns the artwork's full details, from cache when fresh.
    func artworkDetail(id: Int) async throws -> ArtworkDetail

    /// User-initiated refresh of ONE artwork: deletes its cached detail and
    /// downloads a fresh copy, leaving the rest of the cache untouched.
    func refreshArtworkDetail(id: Int) async throws -> ArtworkDetail

    /// The result set's total page count, stored on the first download after
    /// each cache wipe. nil until the first page has ever been downloaded.
    /// Use it to decide whether more pages exist to request.
    func totalPages() async -> Int?

    /// Deletes every cached page, artwork, and detail, including the stored
    /// total page count.
    func clearCache() async throws
}
