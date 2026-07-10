//
//  ArtworkCacheContainerFactory.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData

enum ArtworkCacheContainerFactory {
    /// Builds the ModelContainer for the artwork cache schema.
    /// Pass inMemoryOnly: true in tests for a fast, isolated, disposable store.
    static func make(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            CachedSearchPageEntity.self,
            CachedArtworkEntity.self,
            CachedArtworkDetailEntity.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
