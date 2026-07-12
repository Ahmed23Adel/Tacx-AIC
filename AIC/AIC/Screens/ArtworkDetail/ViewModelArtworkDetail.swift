//
//  ViewModelArtworkDetail.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation
import Observation
import os

@Observable
final class ViewModelArtworkDetail {
    let artworkId: Int
    private let repository: CachedArtworkRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol

    private(set) var detail: ArtworkDetail?
    private(set) var fullDescription: AttributedString?
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var errorMessage: String?
    private(set) var showsFullDescription = false

    /// What Retry should re-attempt: the operation that failed.
    private enum RetryIntent {
        case load
        case refresh
    }

    private var retryIntent: RetryIntent?

    init(
        artworkId: Int,
        repository: CachedArtworkRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.artworkId = artworkId
        self.repository = repository
        self.networkMonitor = networkMonitor
    }

    // MARK: - Display state

    var showsOfflineBanner: Bool {
        isOffline && detail != nil
    }

    var showsWaitingForConnection: Bool {
        isOffline && detail == nil && isLoading
    }

    var showsInitialLoading: Bool {
        !isOffline && detail == nil && isLoading
    }

    var showsError: Bool {
        errorMessage != nil
    }

    var showsDescriptionSection: Bool {
        detail?.shortDescription != nil || fullDescription != nil
    }

    /// The expand/collapse button only exists when there is a long
    /// description to reveal.
    var canToggleDescription: Bool {
        fullDescription != nil
    }

    var descriptionToggleTitle: String {
        if showsFullDescription { return "Show less" }
        return detail?.shortDescription == nil ? "Show description" : "Read more"
    }

    // MARK: - Actions

    func onAppear() async {
        guard detail == nil else { return }
        AppLogger.viewModel.debug("detail \(self.artworkId, privacy: .public): onAppear — loading")
        await loadDetail()
    }

    /// Pull-to-refresh: delete THIS artwork's cached detail and download a
    /// fresh copy. Current content stays visible until replaced.
    func refresh() async {
        AppLogger.viewModel.notice("detail \(self.artworkId, privacy: .public): pull-to-refresh")
        retryIntent = .refresh
        do {
            let fresh = try await repository.refreshArtworkDetail(id: artworkId)
            apply(fresh)
        } catch {
            handle(error)
        }
    }

    func retry() async {
        dismissError()
        AppLogger.viewModel.notice("detail \(self.artworkId, privacy: .public): retry (intent: \(String(describing: self.retryIntent), privacy: .public))")
        switch retryIntent {
        case .refresh:
            await refresh()
        case .load, nil:
            await loadDetail()
        }
    }

    func toggleDescription() {
        showsFullDescription.toggle()
    }

    func dismissError() {
        errorMessage = nil
    }

    /// Long-lived: mirrors the monitor's stream into UI state. Observational
    /// only — data requests are never gated on it.
    func observeConnectivity() async {
        for await isConnected in await networkMonitor.connectionUpdates() {
            isOffline = !isConnected
        }
    }

    // MARK: - Loading

    private func loadDetail() async {
        retryIntent = .load
        isLoading = true
        defer { isLoading = false }

        do {
            let detail = try await repository.artworkDetail(id: artworkId)
            apply(detail)
        } catch {
            handle(error)
        }
    }

    private func apply(_ detail: ArtworkDetail) {
        self.detail = detail
        fullDescription = detail.description.flatMap { HTMLText.attributedString(fromHTML: $0) }
        retryIntent = nil
    }

    private func handle(_ error: Error) {
        AppLogger.viewModel.error("detail \(self.artworkId, privacy: .public): surfacing error to user — \(String(describing: error), privacy: .public)")
        // NetworkError and LocalStoreError both provide user-facing
        // LocalizedError messages; localizedDescription is safe to show.
        errorMessage = error.localizedDescription
    }
}
