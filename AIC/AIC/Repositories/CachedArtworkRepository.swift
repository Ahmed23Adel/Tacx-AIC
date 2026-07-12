//
//  CachedArtworkRepository.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import os

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
            let age = Int(dateProvider.now.timeIntervalSince(cached.insertedAt))
            AppLogger.cache.debug("page \(page, privacy: .public): cache HIT (age \(age, privacy: .public)s) — serving \(cached.artworks.count, privacy: .public) artworks, no network")
            let totalPages = try? await pageStore.fetchTotalPages()
            return ArtworkPage(artworks: cached.artworks, totalPages: totalPages ?? nil)
        }

        AppLogger.cache.notice("page \(page, privacy: .public): cache MISS/STALE — requesting network access")
        await networkMonitor.waitForConnection()

        do {
            let (artworks, pagination) = try await remote.searchArtworks(page: page)
            AppLogger.cache.info("page \(page, privacy: .public): downloaded \(artworks.count, privacy: .public) artworks, totalPages=\(pagination.totalPages, privacy: .public)")

            try? await pageStore.savePage(page, artworks: artworks)

            if await totalPages() == nil {
                try? await pageStore.saveTotalPages(pagination.totalPages)
            }

            return ArtworkPage(artworks: artworks, totalPages: pagination.totalPages)
        } catch {
            AppLogger.cache.error("page \(page, privacy: .public): download FAILED — \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func totalPages() async -> Int? {
        (try? await pageStore.fetchTotalPages()) ?? nil
    }

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        if let cached = try? await detailStore.fetchDetail(id: id), isFresh(cached.insertedAt) {
            let age = Int(dateProvider.now.timeIntervalSince(cached.insertedAt))
            AppLogger.cache.debug("artwork \(id, privacy: .public): cache HIT (age \(age, privacy: .public)s), no network")
            return cached.detail
        }
        AppLogger.cache.notice("artwork \(id, privacy: .public): cache MISS/STALE — requesting network access")
        return try await downloadDetail(id: id)
    }

    func refreshArtworkDetail(id: Int) async throws -> ArtworkDetail {
        AppLogger.cache.notice("artwork \(id, privacy: .public): user-initiated refresh — deleting cached copy")
        // Deletion failure propagates: like clearCache, the delete IS part of
        // what the user asked for. The download then bypasses any cache read.
        try await detailStore.deleteDetail(id: id)
        return try await downloadDetail(id: id)
    }

    private func downloadDetail(id: Int) async throws -> ArtworkDetail {
        await networkMonitor.waitForConnection()

        do {
            let detail = try await remote.artworkDetail(id: id)
            AppLogger.cache.info("artwork \(id, privacy: .public): downloaded successfully")

            // Cache writes are best-effort: a failed save must not fail the request.
            try? await detailStore.saveDetail(detail)

            return detail
        } catch {
            AppLogger.cache.error("artwork \(id, privacy: .public): download FAILED — \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func clearCache() async throws {
        AppLogger.cache.notice("clearCache: wiping all pages, artworks, and details")
        try await pageStore.deleteAllPages()
        try await detailStore.deleteAllDetails()
        AppLogger.cache.notice("clearCache: done")
    }

    private func isFresh(_ insertedAt: Date) -> Bool {
        dateProvider.now.timeIntervalSince(insertedAt) < timeToLive
    }
}
