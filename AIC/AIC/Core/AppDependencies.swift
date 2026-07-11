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

        // force try/unwrap OK: without the cache container or a valid base URL
        // the app cannot function; failing at launch is the correct outcome.
        let container = try! ArtworkCacheContainerFactory.make()
        let localStore = SwiftDataArtworkLocalStore(modelContainer: container)

        let requester = AlamofireAPIRequester(baseURL: URL(string: AppConstants.API.baseURL)!)
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
