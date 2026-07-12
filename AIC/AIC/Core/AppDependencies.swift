//
//  AppDependencies.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation

/// Composition root: the single place where the concrete dependency graph is
/// assembled. Everything below receives protocols; nothing below constructs
/// its own dependencies.
final class AppDependencies {
    let artworkRepository: CachedArtworkRepositoryProtocol
    let networkMonitor: NetworkMonitorProtocol

    init() {
        KingfisherConfigurator.configure()

        let monitor = NetworkMonitor()

        // Resilient: a corrupt cache is wiped and rebuilt, and a broken disk
        // degrades to in-memory — the app launches instead of crashing.
        let container = ArtworkCacheContainerFactory.makeResilient()
        let localStore = SwiftDataArtworkLocalStore(modelContainer: container)

        let requester = AlamofireAPIRequester(baseURL: AppConstants.API.baseURL)
        let remote = ArtworkRepository(apiRequester: requester)

        artworkRepository = CachedArtworkRepository(
            remote: remote,
            pageStore: localStore,
            detailStore: localStore,
            networkMonitor: monitor
        )
        networkMonitor = monitor
    }
}
