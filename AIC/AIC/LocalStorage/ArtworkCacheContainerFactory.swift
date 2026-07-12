//
//  ArtworkCacheContainerFactory.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData
import os

enum ArtworkCacheContainerFactory {
    static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "ArtworkCache.store")
    }

    static func make(inMemoryOnly: Bool = false, url: URL = defaultStoreURL) throws -> ModelContainer {
        let schema = Schema([
            CachedSearchPageEntity.self,
            CachedArtworkEntity.self,
            CachedArtworkDetailEntity.self,
            CachedSearchMetadataEntity.self,
        ])
        let configuration = inMemoryOnly
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Best-effort container for app launch. A cache is disposable and
    /// rebuildable from the network, so it must never crash the app:
    ///   1. try the on-disk store,
    ///   2. if corrupt/incompatible, wipe it and retry (also the schema-
    ///      migration policy: a format change just resets the cache),
    ///   3. if the disk is unusable, degrade to in-memory so the app still
    ///      launches — caching just won't persist across launches.
    static func makeResilient() -> ModelContainer {
        resilientContainer(
            make: { try make(inMemoryOnly: $0, url: $1) },
            storeURL: defaultStoreURL,
            removeItem: removeStore
        )
    }

    /// Deletes the on-disk store; missing file is a no-op. Internal so the
    /// wipe step is directly testable.
    static func removeStore(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Internal recovery policy with injectable steps so every branch —
    /// including the corrupt-store and disk-unusable paths — is testable
    /// without a real corrupt store on disk.
    static func resilientContainer(
        make: (_ inMemoryOnly: Bool, _ url: URL) throws -> ModelContainer,
        storeURL: URL,
        removeItem: (URL) -> Void
    ) -> ModelContainer {
        if let container = try? make(false, storeURL) {
            AppLogger.storage.debug("cache container opened normally on disk")
            return container
        }

        // Corrupt or schema-incompatible store: rebuildable from the network.
        AppLogger.storage.error("cache container failed to open — wiping store and retrying")
        removeItem(storeURL)
        if let container = try? make(false, storeURL) {
            AppLogger.storage.notice("cache container recreated on disk after wipe")
            return container
        }

        // Disk unusable entirely — degrade to in-memory. force unwrap OK:
        // an in-memory store with a valid schema has no external dependency
        // that can fail; only a malformed schema would, which is a programmer
        // error caught in development (same category as a bad URL literal).
        AppLogger.storage.fault("disk store unusable after wipe — degrading to IN-MEMORY cache (no persistence across launches)")
        return try! make(true, storeURL)
    }
}
