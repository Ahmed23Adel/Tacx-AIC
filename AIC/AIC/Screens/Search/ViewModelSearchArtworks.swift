//
//  ViewModelSearchArtworks.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation
import Observation
import os

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

    private var currentPage = 0

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

    var showsOfflineBanner: Bool {
        isOffline && !artworks.isEmpty
    }

    var showsWaitingForConnection: Bool {
        isOffline && artworks.isEmpty && isLoading
    }

    var showsInitialLoading: Bool {
        !isOffline && artworks.isEmpty && isLoading
    }

    var showsError: Bool {
        errorMessage != nil
    }

    var showsEndOfList: Bool {
        !artworks.isEmpty && !paginationTracker.hasMorePages(currentPage: currentPage, totalPages: totalPages)
    }

    // MARK: - Actions

    func onAppear() async {
        guard artworks.isEmpty else { return }
        AppLogger.viewModel.debug("search: onAppear — loading page 1")
        await loadFirstPage()
    }

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

        AppLogger.viewModel.debug("search: row \(index, privacy: .public)/\(self.artworks.count, privacy: .public) triggered prefetch of page \(self.currentPage + 1, privacy: .public)")
        await loadNextPage()
    }

    func retry() async {
        dismissError()
        AppLogger.viewModel.notice("search: retry (intent: \(String(describing: self.retryIntent), privacy: .public))")
        switch retryIntent {
        case .refresh:
            await refresh()
        case .nextPage:
            await loadNextPage()
        case .firstPage, nil:
            await loadFirstPage()
        }
    }

    func refresh() async {
        AppLogger.viewModel.notice("search: pull-to-refresh — clearing cache and reloading page 1")
        retryIntent = .refresh
        do {
            try await repository.clearCache()
            resetPagination()
            await load(page: 1)
        } catch {
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

    private func appendUnique(_ newArtworks: [Artwork]) {
        let existingIds = Set(artworks.map(\.id))
        artworks += newArtworks.filter { !existingIds.contains($0.id) }
    }

    private func handle(_ error: Error) {
        AppLogger.viewModel.error("search: surfacing error to user — \(String(describing: error), privacy: .public)")
        errorMessage = error.localizedDescription
    }
}
