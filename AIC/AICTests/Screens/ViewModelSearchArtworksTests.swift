//
//  ViewModelSearchArtworksTests.swift
//  AICTests
//
//  The search screen's contract: loading flows, infinite scroll decisions,
//  pull-to-refresh, intent-aware retry, display states, and connectivity
//  observation. Repository and monitor are mocks; the tracker is the real
//  pure value, configured per test where needed.
//

import XCTest
@testable import AIC

final class ViewModelSearchArtworksTests: XCTestCase {

    private var sut: ViewModelSearchArtworks!
    private var repository: MockCachedArtworkRepository!
    private var monitor: MockNetworkMonitor!

    override func setUp() {
        super.setUp()
        repository = MockCachedArtworkRepository()
        monitor = MockNetworkMonitor()
        sut = ViewModelSearchArtworks(repository: repository, networkMonitor: monitor)
    }

    override func tearDown() {
        sut = nil
        repository = nil
        monitor = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func stubPage(_ page: Int, ids: ClosedRange<Int>, totalPages: Int? = 13) {
        repository.stubbedPages[page] = .success(Fixtures.artworkPage(ids: ids, totalPages: totalPages))
    }

    /// Loads page 1 with 20 artworks (ids 1...20) as a common starting state.
    private func loadInitialPage(totalPages: Int? = 13) async {
        stubPage(1, ids: 1...20, totalPages: totalPages)
        await sut.onAppear()
    }

    // MARK: - onAppear

    func test_onAppear_loadsFirstPage() async {
        await loadInitialPage()

        XCTAssertEqual(repository.searchedPages, [1])
        XCTAssertEqual(sut.artworks.count, 20)
        XCTAssertEqual(sut.totalPages, 13)
    }

    func test_onAppear_calledAgainWithContent_doesNotReload() async {
        await loadInitialPage()

        await sut.onAppear()

        XCTAssertEqual(repository.searchedPages, [1], "onAppear must be idempotent once content exists")
    }

    func test_onAppear_onFailure_setsErrorMessageAndKeepsListEmpty() async {
        repository.stubbedPages[1] = .failure(NetworkError.serverError(statusCode: 500))

        await sut.onAppear()

        XCTAssertEqual(sut.errorMessage, "The server responded with an error (code 500).")
        XCTAssertTrue(sut.artworks.isEmpty)
        XCTAssertTrue(sut.showsError)
    }

    func test_onAppear_finishesWithLoadingFalse() async {
        await loadInitialPage()
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Display states while loading (via suspended repository)

    func test_showsInitialLoading_whileFirstPageIsInFlightOnline() async {
        stubPage(1, ids: 1...20)
        repository.suspendNextSearch = true

        let loading = Task { await sut.onAppear() }
        while repository.searchedPages.isEmpty { await Task.yield() }

        XCTAssertTrue(sut.showsInitialLoading)
        XCTAssertFalse(sut.showsWaitingForConnection, "online loading is a spinner, not the offline placeholder")

        repository.resumeSuspendedSearch()
        await loading.value
        XCTAssertFalse(sut.showsInitialLoading)
    }

    func test_showsWaitingForConnection_whileLoadingOfflineWithEmptyList() async {
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity() // isOffline = true
        stubPage(1, ids: 1...20)
        repository.suspendNextSearch = true

        let loading = Task { await sut.onAppear() }
        while repository.searchedPages.isEmpty { await Task.yield() }

        XCTAssertTrue(sut.showsWaitingForConnection)
        XCTAssertFalse(sut.showsInitialLoading, "offline loading shows the waiting placeholder, not the spinner")

        repository.resumeSuspendedSearch()
        await loading.value
    }

    // MARK: - Infinite scroll

    func test_onRowAppear_nearEnd_loadsNextPageAndAppends() async {
        await loadInitialPage()
        stubPage(2, ids: 21...40)

        await sut.onRowAppear(sut.artworks[15]) // 5 from the end of 20

        XCTAssertEqual(repository.searchedPages, [1, 2])
        XCTAssertEqual(sut.artworks.count, 40)
        XCTAssertEqual(sut.artworks.map(\.id), Array(1...40), "page 2 must append after page 1 in order")
    }

    func test_onRowAppear_earlyRow_doesNotLoad() async {
        await loadInitialPage()

        await sut.onRowAppear(sut.artworks[5])

        XCTAssertEqual(repository.searchedPages, [1])
    }

    func test_onRowAppear_onLastPage_doesNotLoad() async {
        await loadInitialPage(totalPages: 1)

        await sut.onRowAppear(sut.artworks[19])

        XCTAssertEqual(repository.searchedPages, [1], "currentPage == totalPages means no more requests")
    }

    func test_onRowAppear_whileNextPageInFlight_doesNotLoadTwice() async {
        await loadInitialPage()
        stubPage(2, ids: 21...40)
        repository.suspendNextSearch = true

        let firstTrigger = Task { await sut.onRowAppear(sut.artworks[19]) }
        while repository.searchedPages.count < 2 { await Task.yield() }

        await sut.onRowAppear(sut.artworks[18]) // second row appears mid-flight

        repository.resumeSuspendedSearch()
        await firstTrigger.value

        XCTAssertEqual(repository.searchedPages, [1, 2], "busy guard must prevent duplicate page requests")
    }

    func test_onRowAppear_withUnknownArtwork_doesNothing() async {
        await loadInitialPage()

        await sut.onRowAppear(Fixtures.artwork(id: 999_999))

        XCTAssertEqual(repository.searchedPages, [1])
    }

    func test_onRowAppear_isLoadingNextPage_visibleDuringFetch() async {
        await loadInitialPage()
        stubPage(2, ids: 21...40)
        repository.suspendNextSearch = true

        let trigger = Task { await sut.onRowAppear(sut.artworks[19]) }
        while repository.searchedPages.count < 2 { await Task.yield() }

        XCTAssertTrue(sut.isLoadingNextPage)
        XCTAssertFalse(sut.isLoading, "next-page loading must not trigger full-screen states")

        repository.resumeSuspendedSearch()
        await trigger.value
        XCTAssertFalse(sut.isLoadingNextPage)
    }

    // Regression: the API's rank drift can deliver the same artwork on two
    // pages; duplicate ids would break SwiftUI ForEach identity.
    func test_onRowAppear_pageWithDuplicateArtworks_appendsOnlyNewOnes() async {
        await loadInitialPage()
        stubPage(2, ids: 15...34) // ids 15...20 overlap page 1

        await sut.onRowAppear(sut.artworks[19])

        XCTAssertEqual(sut.artworks.count, 34, "overlapping ids must be dropped, not duplicated")
        XCTAssertEqual(Set(sut.artworks.map(\.id)).count, sut.artworks.count, "all ids must be unique")
    }

    func test_onRowAppear_failure_keepsExistingContentAndShowsError() async {
        await loadInitialPage()
        repository.stubbedPages[2] = .failure(NetworkError.transport(URLError(.timedOut)))

        await sut.onRowAppear(sut.artworks[19])

        XCTAssertEqual(sut.artworks.count, 20, "a failed next page must not disturb loaded content")
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - End of list

    func test_showsEndOfList_onLastPage_isTrue() async {
        await loadInitialPage(totalPages: 1)
        XCTAssertTrue(sut.showsEndOfList)
    }

    func test_showsEndOfList_withMorePages_isFalse() async {
        await loadInitialPage(totalPages: 13)
        XCTAssertFalse(sut.showsEndOfList)
    }

    func test_showsEndOfList_withEmptyList_isFalse() async {
        XCTAssertFalse(sut.showsEndOfList)
    }

    // MARK: - Pull-to-refresh

    func test_refresh_clearsCacheAndReloadsPageOne() async {
        await loadInitialPage()
        stubPage(1, ids: 100...119) // fresh server content after the wipe

        await sut.refresh()

        XCTAssertEqual(repository.clearCacheCallCount, 1)
        XCTAssertEqual(repository.searchedPages, [1, 1])
        XCTAssertEqual(sut.artworks.map(\.id), Array(100...119), "refresh must replace, not append")
    }

    func test_refresh_resetsPagination() async {
        await loadInitialPage()
        stubPage(2, ids: 21...40)
        await sut.onRowAppear(sut.artworks[15]) // currentPage is now 2

        stubPage(1, ids: 100...119)
        await sut.refresh()
        stubPage(2, ids: 120...139)
        await sut.onRowAppear(sut.artworks[15])

        XCTAssertEqual(repository.searchedPages, [1, 2, 1, 2], "after refresh the next page must be 2 again, not 3")
    }

    func test_refresh_whenClearCacheFails_showsErrorAndKeepsContent() async {
        await loadInitialPage()
        repository.clearCacheError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)

        await sut.refresh()

        XCTAssertEqual(sut.errorMessage, "Data could not be saved on this device.")
        XCTAssertEqual(sut.artworks.count, 20, "failed refresh must leave content untouched")
        XCTAssertEqual(repository.searchedPages, [1], "no reload after a failed cache clear")
    }

    // MARK: - Retry (intent-aware)

    func test_retry_afterFirstPageFailure_retriesFirstPage() async {
        repository.stubbedPages[1] = .failure(NetworkError.serverError(statusCode: 500))
        await sut.onAppear()

        stubPage(1, ids: 1...20)
        await sut.retry()

        XCTAssertEqual(repository.searchedPages, [1, 1])
        XCTAssertEqual(sut.artworks.count, 20)
        XCTAssertNil(sut.errorMessage)
    }

    func test_retry_afterNextPageFailure_retriesSamePageNotTheOneAfter() async {
        await loadInitialPage()
        repository.stubbedPages[2] = .failure(NetworkError.serverError(statusCode: 500))
        await sut.onRowAppear(sut.artworks[19])

        stubPage(2, ids: 21...40)
        await sut.retry()

        XCTAssertEqual(repository.searchedPages, [1, 2, 2], "retry must re-request the failed page, not advance")
        XCTAssertEqual(sut.artworks.count, 40)
    }

    // Regression: retry after a failed refresh used to advance pagination
    // instead of re-attempting the refresh.
    func test_retry_afterFailedRefresh_reattemptsTheRefresh() async {
        await loadInitialPage()
        repository.clearCacheError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)
        await sut.refresh()

        repository.clearCacheError = nil
        stubPage(1, ids: 100...119)
        await sut.retry()

        XCTAssertEqual(repository.clearCacheCallCount, 2, "retry must re-run the refresh, not load a next page")
        XCTAssertEqual(sut.artworks.map(\.id), Array(100...119))
    }

    func test_retry_withNoPriorFailure_loadsFirstPage() async {
        stubPage(1, ids: 1...20)

        await sut.retry()

        XCTAssertEqual(repository.searchedPages, [1])
    }

    // MARK: - Error dismissal

    func test_dismissError_clearsMessage() async {
        repository.stubbedPages[1] = .failure(NetworkError.serverError(statusCode: 500))
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

    // MARK: - Offline banner

    func test_showsOfflineBanner_offlineWithContent_isTrue() async {
        await loadInitialPage()
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity()

        XCTAssertTrue(sut.showsOfflineBanner)
    }

    func test_showsOfflineBanner_offlineWithEmptyList_isFalse() async {
        await monitor.setConnectionSequence([false])
        await sut.observeConnectivity()

        XCTAssertFalse(sut.showsOfflineBanner)
    }

    func test_showsOfflineBanner_onlineWithContent_isFalse() async {
        await loadInitialPage()
        await monitor.setConnectionSequence([true])
        await sut.observeConnectivity()

        XCTAssertFalse(sut.showsOfflineBanner)
    }

    // MARK: - Memory

    func test_viewModel_deallocates_noMemoryLeak() {
        var viewModel: ViewModelSearchArtworks? = ViewModelSearchArtworks(
            repository: MockCachedArtworkRepository(),
            networkMonitor: MockNetworkMonitor()
        )
        weak var weakReference = viewModel

        viewModel = nil

        XCTAssertNil(weakReference, "Potential memory leak: ViewModelSearchArtworks not deallocated")
    }
}
