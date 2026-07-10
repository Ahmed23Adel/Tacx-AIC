//
//  ArtworkDetailLocalStoreProtocol.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

protocol ArtworkDetailLocalStoreProtocol: Sendable {
    /// Returns the cached detail, or nil when that artwork was never stored.
    func fetchDetail(id: Int) async throws -> CachedArtworkDetail?

    /// Stores a detail, replacing any previous cache for that artwork
    /// and stamping it with the current time.
    func saveDetail(_ detail: ArtworkDetail) async throws

    /// Removes a cached detail if present.
    func deleteDetail(id: Int) async throws
}
