//
//  ViewSearchArtworks.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

struct ViewSearchArtworks: View {
    @Environment(Coordinator.self) private var coordinator
    @State private var viewModel: ViewModelSearchArtworks

    init(viewModel: ViewModelSearchArtworks) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Artworks")
            .task { await viewModel.observeConnectivity() }
            .task { await viewModel.onAppear() }
            .alert("Something Went Wrong", isPresented: errorAlertBinding) {
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.showsWaitingForConnection {
            WaitingForConnectionView()
        } else if viewModel.showsInitialLoading {
            loadingView
        } else {
            artworkList
        }
    }

    private var loadingView: some View {
        ProgressView("Loading artworks…")
            .accessibilityIdentifier("search.loading")
    }

    private var artworkList: some View {
        List {
            ForEach(viewModel.artworks) { artwork in
                Button {
                    coordinator.goToArtworkDetail(id: artwork.id)
                } label: {
                    ArtworkRowView(artwork: artwork)
                }
                .buttonStyle(.plain)
                .onAppear {
                    Task { await viewModel.onRowAppear(artwork) }
                }
            }
            listFooter
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
        .accessibilityIdentifier("search.list")
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.showsOfflineBanner {
                OfflineBannerView()
            }
        }
    }

    @ViewBuilder
    private var listFooter: some View {
        if viewModel.isLoadingNextPage {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("search.nextPageLoading")
        } else if viewModel.showsEndOfList {
            Text("You've seen all \(viewModel.artworks.count) artworks")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("search.endOfList")
        }
    }

    /// The alert presents whenever an error message exists; dismissing the
    /// alert clears it.
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showsError },
            set: { isPresented in
                if !isPresented { viewModel.dismissError() }
            }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ViewSearchArtworks(viewModel: ViewModelSearchArtworks(
            repository: PreviewArtworkRepository(),
            networkMonitor: PreviewNetworkMonitor()
        ))
    }
    .environment(Coordinator())
}

/// Preview-only stubs: previews must not touch network or disk.
private struct PreviewArtworkRepository: CachedArtworkRepositoryProtocol {
    func searchArtworks(page: Int) async throws -> ArtworkPage {
        ArtworkPage(
            artworks: [
                Artwork(id: 95998, title: "Old Man with a Gold Chain", imageId: nil, dateDisplay: "1631"),
                Artwork(id: 90536, title: "Seated Female Nude", imageId: nil, dateDisplay: "1660/62"),
            ],
            totalPages: 13
        )
    }

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        throw NetworkError.invalidURL
    }

    func refreshArtworkDetail(id: Int) async throws -> ArtworkDetail {
        throw NetworkError.invalidURL
    }

    func totalPages() async -> Int? { 13 }

    func clearCache() async throws {}
}

private struct PreviewNetworkMonitor: NetworkMonitorProtocol {
    func waitForConnection() async {}

    func connectionUpdates() async -> AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(true)
            continuation.finish()
        }
    }
}
#endif
