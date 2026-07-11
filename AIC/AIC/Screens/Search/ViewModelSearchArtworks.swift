//
//  ViewModelSearchArtworks.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation
import Observation

@Observable
final class ViewModelSearchArtworks {
    private let repository: CachedArtworkRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private let paginationTracker: PaginationTracker

    private(set) var artworks: [Artwork] = []
    private(set) var totalPages: Int?
    private(set) var isLoading = false
    private(set) var isLoadingNextPage = false
    private(set) var isOffline = false
    private(set) var errorMessage: String?

    /// Last successfully loaded page; 0 = nothing loaded yet.
    private var currentPage = 0

    /// What Retry should re-attempt: always the operation that failed,
    /// not a guess from list state (a failed refresh must retry the refresh,
    /// never advance pagination).
    private enum RetryIntent {
        case firstPage
        case nextPage
        case refresh
    }

    private var retryIntent: RetryIntent?

    init(
        repository: CachedArtworkRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol,
        paginationTracker: PaginationTracker = PaginationTracker()
    ) {
        self.repository = repository
        self.networkMonitor = networkMonitor
        self.paginationTracker = paginationTracker
    }

    // MARK: - Display state

    /// Content is on screen but the device is offline: passive information only.
    var showsOfflineBanner: Bool {
        isOffline && !artworks.isEmpty
    }

    /// Nothing to show and the request is parked at the connectivity gate:
    /// a waiting state, not an error — the call completes itself on reconnect.
    var showsWaitingForConnection: Bool {
        isOffline && artworks.isEmpty && isLoading
    }

    var showsInitialLoading: Bool {
        !isOffline && artworks.isEmpty && isLoading
    }

    var showsError: Bool {
        errorMessage != nil
    }

    /// Every page is on screen: show the end-of-list footer instead of a spinner.
    var showsEndOfList: Bool {
        !artworks.isEmpty && !paginationTracker.hasMorePages(currentPage: currentPage, totalPages: totalPages)
    }

    // MARK: - Actions

    func onAppear() async {
        guard artworks.isEmpty else { return }
        await loadFirstPage()
    }

    /// Called as each row becomes visible; the tracker decides whether this
    /// row's appearance means the next page should start downloading.
    func onRowAppear(_ artwork: Artwork) async {
        guard let index = artworks.firstIndex(where: { $0.id == artwork.id }) else { return }

        let shouldLoad = paginationTracker.shouldLoadNextPage(
            visibleIndex: index,
            itemCount: artworks.count,
            currentPage: currentPage,
            totalPages: totalPages,
            isBusy: isLoading || isLoadingNextPage
        )
        guard shouldLoad else { return }

        await loadNextPage()
    }

    func retry() async {
        dismissError()
        switch retryIntent {
        case .refresh:
            await refresh()
        case .nextPage:
            await loadNextPage()
        case .firstPage, nil:
            await loadFirstPage()
        }
    }

    /// Pull-to-refresh: wipe every cached page, artwork, and detail, then
    /// start over from page 1. Current content stays on screen until the
    /// fresh page 1 replaces it — never blank the list under the user.
    func refresh() async {
        retryIntent = .refresh
        do {
            try await repository.clearCache()
            resetPagination()
            await load(page: 1)
        } catch {
            // clearCache failing is a real, user-initiated operation failing:
            // surface it and keep the current content untouched.
            handle(error)
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func observeConnectivity() async {
        for await isConnected in await networkMonitor.connectionUpdates() {
            isOffline = !isConnected
        }
    }

    // MARK: - Loading

    private func loadFirstPage() async {
        retryIntent = .firstPage
        isLoading = true
        defer { isLoading = false }
        await load(page: 1)
    }

    private func resetPagination() {
        currentPage = 0
        totalPages = nil
    }

    private func loadNextPage() async {
        retryIntent = .nextPage
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }
        await load(page: currentPage + 1)
    }

    private func load(page pageNumber: Int) async {
        do {
            let page = try await repository.searchArtworks(page: pageNumber)
            apply(page, loadedPage: pageNumber)
        } catch {
            handle(error)
        }
    }

    private func apply(_ page: ArtworkPage, loadedPage: Int) {
        if loadedPage == 1 {
            artworks = page.artworks
        } else {
            appendUnique(page.artworks)
        }
        totalPages = page.totalPages
        currentPage = loadedPage
        retryIntent = nil
    }

    /// The API's relevance ranking drifts between requests, so an artwork can
    /// legitimately arrive on two pages. Duplicate ids would break SwiftUI's
    /// ForEach identity — keep the first occurrence only.
    private func appendUnique(_ newArtworks: [Artwork]) {
        let existingIds = Set(artworks.map(\.id))
        artworks += newArtworks.filter { !existingIds.contains($0.id) }
    }

    private func handle(_ error: Error) {
        // NetworkError and LocalStoreError both provide user-facing
        // LocalizedError messages; localizedDescription is safe to show.
        errorMessage = error.localizedDescription
    }
}
