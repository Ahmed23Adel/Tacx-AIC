//
//  ViewModelArtworkDetailTests.swift
//  AICTests
//
//  The detail screen's contract: load on appear, per-artwork refresh,
//  intent-aware retry, expandable description, offline/error display states.
//

import XCTest
@testable import AIC

final class ViewModelArtworkDetailTests: XCTestCase {

    private let artworkId = 95998

    private var sut: ViewModelArtworkDetail!
    private var repository: MockCachedArtworkRepository!
    private var monitor: MockNetworkMonitor!

    override func setUp() {
        super.setUp()
        repository = MockCachedArtworkRepository()
        monitor = MockNetworkMonitor()
        sut = ViewModelArtworkDetail(artworkId: artworkId, repository: repository, networkMonitor: monitor)
    }

    override func tearDown() {
        sut = nil
        repository = nil
        monitor = nil
        super.tearDown()
    }

    // MARK: - onAppear

    func test_onAppear_loadsDetailForItsArtworkId() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))

        await sut.onAppear()

        XCTAssertEqual(repository.requestedDetailIds, [artworkId])
        XCTAssertEqual(sut.detail?.id, artworkId)
    }

    func test_onAppear_calledAgainWithDetail_doesNotReload() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        await sut.onAppear()

        await sut.onAppear()

        XCTAssertEqual(repository.requestedDetailIds, [artworkId], "onAppear must be idempotent once loaded")
    }

    func test_onAppear_onFailure_setsErrorAndKeepsDetailNil() async {
        repository.stubbedDetailResult = .failure(NetworkError.serverError(statusCode: 500))

        await sut.onAppear()

        XCTAssertEqual(sut.errorMessage, "The server responded with an error (code 500).")
        XCTAssertNil(sut.detail)
        XCTAssertTrue(sut.showsError)
    }

    func test_onAppear_finishesWithLoadingFalse() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        await sut.onAppear()
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Display states while loading

    func test_showsInitialLoading_whileInFlightOnline() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        repository.suspendNextDetail = true

        let loading = Task { await sut.onAppear() }
        while repository.requestedDetailIds.isEmpty { await Task.yield() }

        XCTAssertTrue(sut.showsInitialLoading)
        XCTAssertFalse(sut.showsWaitingForConnection)

        repository.resumeSuspendedDetail()
        await loading.value
        XCTAssertFalse(sut.showsInitialLoading)
    }

    func test_showsWaitingForConnection_whileInFlightOfflineWithNoDetail() async {
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity()
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        repository.suspendNextDetail = true

        let loading = Task { await sut.onAppear() }
        while repository.requestedDetailIds.isEmpty { await Task.yield() }

        XCTAssertTrue(sut.showsWaitingForConnection)
        XCTAssertFalse(sut.showsInitialLoading)

        repository.resumeSuspendedDetail()
        await loading.value
    }

    // MARK: - Offline banner

    func test_showsOfflineBanner_offlineWithDetail_isTrue() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        await sut.onAppear()
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity()

        XCTAssertTrue(sut.showsOfflineBanner)
    }

    func test_showsOfflineBanner_offlineWithoutDetail_isFalse() async {
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity()

        XCTAssertFalse(sut.showsOfflineBanner)
    }

    func test_showsOfflineBanner_onlineWithDetail_isFalse() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        await sut.onAppear()
        await monitor.setConnectionSequence([true])
        await sut.observeConnectivity()

        XCTAssertFalse(sut.showsOfflineBanner)
    }

    // MARK: - Refresh

    func test_refresh_requestsPerArtworkRefreshAndReplacesDetail() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId, title: "Old"))
        await sut.onAppear()
        repository.stubbedRefreshDetailResult = .success(Fixtures.artworkDetail(id: artworkId, title: "Fresh"))

        await sut.refresh()

        XCTAssertEqual(repository.refreshedDetailIds, [artworkId])
        XCTAssertEqual(sut.detail?.title, "Fresh")
    }

    func test_refresh_onFailure_showsErrorAndKeepsCurrentDetail() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId, title: "Old"))
        await sut.onAppear()
        repository.stubbedRefreshDetailResult = .failure(NetworkError.transport(URLError(.timedOut)))

        await sut.refresh()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.detail?.title, "Old", "failed refresh must not blank the screen")
    }

    // MARK: - Retry (intent-aware)

    func test_retry_afterLoadFailure_retriesLoad() async {
        repository.stubbedDetailResult = .failure(NetworkError.serverError(statusCode: 500))
        await sut.onAppear()

        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        await sut.retry()

        XCTAssertEqual(repository.requestedDetailIds, [artworkId, artworkId])
        XCTAssertEqual(sut.detail?.id, artworkId)
        XCTAssertNil(sut.errorMessage)
    }

    // Regression pairing: a failed refresh must be retried AS a refresh.
    func test_retry_afterFailedRefresh_reattemptsTheRefresh() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))
        await sut.onAppear()
        repository.stubbedRefreshDetailResult = .failure(NetworkError.serverError(statusCode: 500))
        await sut.refresh()

        repository.stubbedRefreshDetailResult = .success(Fixtures.artworkDetail(id: artworkId, title: "Fresh"))
        await sut.retry()

        XCTAssertEqual(repository.refreshedDetailIds, [artworkId, artworkId], "retry must re-run the refresh")
        XCTAssertEqual(repository.requestedDetailIds, [artworkId], "retry must NOT fall back to a plain load")
        XCTAssertEqual(sut.detail?.title, "Fresh")
    }

    func test_retry_withNoPriorFailure_loads() async {
        repository.stubbedDetailResult = .success(Fixtures.artworkDetail(id: artworkId))

        await sut.retry()

        XCTAssertEqual(repository.requestedDetailIds, [artworkId])
    }

    // MARK: - Description section

    private func detail(short: String?, full: String?) -> ArtworkDetail {
        ArtworkDetail(
            id: artworkId, title: "T", artistDisplay: nil, dateDisplay: nil,
            mediumDisplay: nil, dimensions: nil, placeOfOrigin: nil, creditLine: nil,
            imageId: nil, shortDescription: short, description: full
        )
    }

    func test_apply_withHTMLDescription_computesAttributedFullDescription() async {
        repository.stubbedDetailResult = .success(detail(short: "Short", full: "<p>Full <strong>bold</strong></p>"))

        await sut.onAppear()

        let full = sut.fullDescription
        XCTAssertNotNil(full)
        XCTAssertEqual(String(full!.characters), "Full bold")
    }

    func test_descriptionSection_bothFieldsNil_isHidden() async {
        repository.stubbedDetailResult = .success(detail(short: nil, full: nil))

        await sut.onAppear()

        XCTAssertFalse(sut.showsDescriptionSection)
        XCTAssertFalse(sut.canToggleDescription)
    }

    func test_descriptionSection_shortOnly_visibleButNotTogglable() async {
        repository.stubbedDetailResult = .success(detail(short: "Short", full: nil))

        await sut.onAppear()

        XCTAssertTrue(sut.showsDescriptionSection)
        XCTAssertFalse(sut.canToggleDescription, "no long text to reveal, no button")
    }

    func test_descriptionToggleTitle_withShortPresent_isReadMore() async {
        repository.stubbedDetailResult = .success(detail(short: "Short", full: "<p>Full</p>"))

        await sut.onAppear()

        XCTAssertEqual(sut.descriptionToggleTitle, "Read more")
    }

    func test_descriptionToggleTitle_withoutShort_isShowDescription() async {
        repository.stubbedDetailResult = .success(detail(short: nil, full: "<p>Full</p>"))

        await sut.onAppear()

        XCTAssertEqual(sut.descriptionToggleTitle, "Show description")
    }

    func test_toggleDescription_expandsAndTitleBecomesShowLess() async {
        repository.stubbedDetailResult = .success(detail(short: "Short", full: "<p>Full</p>"))
        await sut.onAppear()

        sut.toggleDescription()

        XCTAssertTrue(sut.showsFullDescription)
        XCTAssertEqual(sut.descriptionToggleTitle, "Show less")
    }

    func test_toggleDescription_twice_collapsesAgain() async {
        repository.stubbedDetailResult = .success(detail(short: "Short", full: "<p>Full</p>"))
        await sut.onAppear()

        sut.toggleDescription()
        sut.toggleDescription()

        XCTAssertFalse(sut.showsFullDescription)
        XCTAssertEqual(sut.descriptionToggleTitle, "Read more")
    }

    // MARK: - Error dismissal

    func test_dismissError_clearsMessage() async {
        repository.stubbedDetailResult = .failure(NetworkError.serverError(statusCode: 500))
        await sut.onAppear()

        sut.dismissError()

        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showsError)
    }

    // MARK: - Connectivity observation

    func test_observeConnectivity_offlineEmission_setsIsOffline() async {
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity()
        XCTAssertTrue(sut.isOffline)
    }

    func test_observeConnectivity_reconnection_clearsIsOffline() async {
        await monitor.setConnectionSequence([false, true])
        await sut.observeConnectivity()
        XCTAssertFalse(sut.isOffline)
    }

    // MARK: - Memory

    func test_viewModel_deallocates_noMemoryLeak() {
        var viewModel: ViewModelArtworkDetail? = ViewModelArtworkDetail(
            artworkId: 1,
            repository: MockCachedArtworkRepository(),
            networkMonitor: MockNetworkMonitor()
        )
        weak var weakReference = viewModel

        viewModel = nil

        XCTAssertNil(weakReference, "Potential memory leak: ViewModelArtworkDetail not deallocated")
    }
}
