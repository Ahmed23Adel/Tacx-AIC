//
//  CachedArtworkRepository.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

final class CachedArtworkRepository: CachedArtworkRepositoryProtocol {
    private let remote: ArtworkRepositoryProtocol
    private let pageStore: SearchResultsLocalStoreProtocol
    private let detailStore: ArtworkDetailLocalStoreProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private let dateProvider: DateProviding
    private let timeToLive: TimeInterval

    init(
        remote: ArtworkRepositoryProtocol,
        pageStore: SearchResultsLocalStoreProtocol,
        detailStore: ArtworkDetailLocalStoreProtocol,
        networkMonitor: NetworkMonitorProtocol,
        dateProvider: DateProviding = SystemDateProvider(),
        timeToLive: TimeInterval = AppConstants.Cache.timeToLive
    ) {
        self.remote = remote
        self.pageStore = pageStore
        self.detailStore = detailStore
        self.networkMonitor = networkMonitor
        self.dateProvider = dateProvider
        self.timeToLive = timeToLive
    }

    func searchArtworks(page: Int) async throws -> ArtworkPage {
        if let cached = try? await pageStore.fetchPage(page), isFresh(cached.insertedAt) {
            let totalPages = try? await pageStore.fetchTotalPages()
            return ArtworkPage(artworks: cached.artworks, totalPages: totalPages ?? nil)
        }

        await networkMonitor.waitForConnection()
        let (artworks, pagination) = try await remote.searchArtworks(page: page)

        try? await pageStore.savePage(page, artworks: artworks)


        if await totalPages() == nil {
            try? await pageStore.saveTotalPages(pagination.totalPages)
        }

        return ArtworkPage(artworks: artworks, totalPages: pagination.totalPages)
    }

    func totalPages() async -> Int? {
        (try? await pageStore.fetchTotalPages()) ?? nil
    }

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        if let cached = try? await detailStore.fetchDetail(id: id), isFresh(cached.insertedAt) {
            return cached.detail
        }

        await networkMonitor.waitForConnection()
        let detail = try await remote.artworkDetail(id: id)

        try? await detailStore.saveDetail(detail)

        return detail
    }

    func clearCache() async throws {
        try await pageStore.deleteAllPages()
        try await detailStore.deleteAllDetails()
    }

    private func isFresh(_ insertedAt: Date) -> Bool {
        dateProvider.now.timeIntervalSince(insertedAt) < timeToLive
    }
}
