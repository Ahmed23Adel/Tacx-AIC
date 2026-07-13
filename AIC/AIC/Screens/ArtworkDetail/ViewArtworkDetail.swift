//
//  ViewArtworkDetail.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI
import Kingfisher

struct ViewArtworkDetail: View {
    @State private var viewModel: ViewModelArtworkDetail
    @Environment(\.displayScale) private var displayScale

    private enum Layout {
        static let heroHeight: CGFloat = 300
    }

    init(viewModel: ViewModelArtworkDetail) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
            ProgressView("Loading artwork…")
                .accessibilityIdentifier("detail.loading")
        } else if let detail = viewModel.detail {
            detailScroll(detail)
        } else {
            Color.clear
        }
    }

    private func detailScroll(_ detail: ArtworkDetail) -> some View {
        // The ScrollView stays inside the safe area so the pull-to-refresh
        // spinner appears below the notch; only the hero image is stretched
        // and pulled up to cover the notch area.
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroImage(imageId: detail.imageId, topInset: geometry.safeAreaInsets.top, availableWidth: geometry.size.width)

                    VStack(alignment: .leading, spacing: 20) {
                        header(detail)
                        chips(detail)
                        facts(detail)
                        descriptionSection(detail)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 32)
            }
            .scrollClipDisabled() // let the hero draw outside the scroll bounds, under the notch
            .refreshable {
                await viewModel.refresh()
            }
            .accessibilityIdentifier("detail.scroll")
            .safeAreaInset(edge: .top, spacing: 0) {
                if viewModel.showsOfflineBanner {
                    OfflineBannerView()
                }
            }
        }
    }

    // MARK: - Sections

    private func heroImage(imageId: String?, topInset: CGFloat, availableWidth: CGFloat) -> some View {
        let displayHeight = Layout.heroHeight + topInset
        let pixelSize = CGSize(width: availableWidth * displayScale, height: displayHeight * displayScale)

        return KFImage(ArtworkImageURL.full(imageId: imageId))
            .setProcessor(DownsamplingImageProcessor(size: pixelSize))
            .scaleFactor(displayScale)
            .cacheOriginalImage()
            .placeholder {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
            .resizable()
            .scaledToFill()
            .frame(width: availableWidth, height: displayHeight) // taller by the notch area it covers
            .clipped()
            .padding(.top, -topInset) // pulled up out of the safe area
            .accessibilityHidden(true)
    }

    private func header(_ detail: ArtworkDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail.title ?? "Untitled")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("detail.title")

            if let artist = detail.artistDisplay {
                Text(artist)
                    .font(.title3)
                    .italic()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("detail.artist")
            }
        }
    }

    // Only the date is a chip — it's always short. Medium can be a full
    // paragraph, so it lives in the facts rows where long values wrap.
    @ViewBuilder
    private func chips(_ detail: ArtworkDetail) -> some View {
        if let date = detail.dateDisplay {
            ChipView(text: date)
        }
    }

    private func facts(_ detail: ArtworkDetail) -> some View {
        VStack(spacing: 12) {
            if let medium = detail.mediumDisplay {
                DetailInfoRow(label: "Medium", value: medium)
            }
            if let dimensions = detail.dimensions {
                DetailInfoRow(label: "Dimensions", value: dimensions)
            }
            if let origin = detail.placeOfOrigin {
                DetailInfoRow(label: "Place of origin", value: origin)
            }
            if let credit = detail.creditLine {
                DetailInfoRow(label: "Credit line", value: credit)
            }
        }
    }

    @ViewBuilder
    private func descriptionSection(_ detail: ArtworkDetail) -> some View {
        if viewModel.showsDescriptionSection {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.showsFullDescription, let full = viewModel.fullDescription {
                    Text(full)
                        .accessibilityIdentifier("detail.fullDescription")
                } else if let short = detail.shortDescription {
                    Text(short)
                        .font(.body)
                        .accessibilityIdentifier("detail.shortDescription")
                }

                if viewModel.canToggleDescription {
                    Button(viewModel.descriptionToggleTitle) {
                        withAnimation {
                            viewModel.toggleDescription()
                        }
                    }
                    .font(.body.weight(.medium))
                    .accessibilityIdentifier("detail.descriptionToggle")
                }
            }
        }
    }

    /// The alert presents whenever an error message exists; dismissing clears it.
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
        ViewArtworkDetail(viewModel: ViewModelArtworkDetail(
            artworkId: 6565,
            repository: PreviewDetailRepository(),
            networkMonitor: PreviewDetailNetworkMonitor()
        ))
    }
    .environment(Coordinator())
}

/// Preview-only stubs: previews must not touch network or disk.
private struct PreviewDetailRepository: CachedArtworkRepositoryProtocol {
    func searchArtworks(page: Int) async throws -> ArtworkPage {
        ArtworkPage(artworks: [], totalPages: 1)
    }

    func artworkDetail(id: Int) async throws -> ArtworkDetail {
        ArtworkDetail(
            id: id,
            title: "American Gothic",
            artistDisplay: "Grant Wood, American, 1891–1942",
            dateDisplay: "1635, printed 1906",
            mediumDisplay: "Oil on beaverboard",
            dimensions: "78 × 65.3 cm",
            placeOfOrigin: "United States",
            creditLine: "Friends of American Art Collection",
            imageId: nil,
            shortDescription: "Grant Wood's meticulous rendering of a farmer and his daughter in front of their Carpenter Gothic house has become one of the most parodied images in American art.",
            description: "<p>Grant Wood's <em>American Gothic</em> has become one of the <strong>most parodied</strong> images in American art.</p>"
        )
    }

    func refreshArtworkDetail(id: Int) async throws -> ArtworkDetail {
        try await artworkDetail(id: id)
    }

    func totalPages() async -> Int? { 1 }

    func clearCache() async throws {}
}

private struct PreviewDetailNetworkMonitor: NetworkMonitorProtocol {
    func waitForConnection() async {}

    func connectionUpdates() async -> AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(true)
            continuation.finish()
        }
    }
}
#endif
