//
//  CachedArtworkRepositoryTests.swift
//  AICTests
//
//  The cache-policy contract: freshness routing, write-once totalPages,
//  parking, error propagation policy, clearCache. All five dependencies
//  are mocks; the clock is frozen; TTL is the production constant.
//

import XCTest
@testable import AIC

final class CachedArtworkRepositoryTests: XCTestCase {

    private static let frozenNow = Date(timeIntervalSince1970: 1_750_000_000)
    private static let ttl = AppConstants.Cache.timeToLive

    private var sut: CachedArtworkRepository!
    private var remote: MockArtworkRemoteRepository!
    private var pageStore: MockSearchResultsLocalStore!
    private var detailStore: MockArtworkDetailLocalStore!
    private var monitor: MockNetworkMonitor!

    override func setUp() {
        super.setUp()
        remote = MockArtworkRemoteRepository()
        pageStore = MockSearchResultsLocalStore()
        detailStore = MockArtworkDetailLocalStore()
        monitor = MockNetworkMonitor()
        sut = CachedArtworkRepository(
            remote: remote,
            pageStore: pageStore,
            detailStore: detailStore,
            networkMonitor: monitor,
            dateProvider: FixedDateProvider(now: Self.frozenNow),
            timeToLive: Self.ttl
        )
    }

    override func tearDown() {
        sut = nil
        remote = nil
        pageStore = nil
        detailStore = nil
        monitor = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func cachedPage(ageSeconds: TimeInterval, artworks: [Artwork] = [Fixtures.artwork()]) -> CachedSearchPage {
        CachedSearchPage(
            pageNumber: 1,
            artworks: artworks,
            insertedAt: Self.frozenNow.addingTimeInterval(-ageSeconds)
        )
    }

    private func stubNetworkSuccess(totalPages: Int = 13) {
        remote.stubbedSearchResult = .success(
            ([Fixtures.artwork(id: 999)], Fixtures.pagination(totalPages: totalPages))
        )
    }

    // MARK: - searchArtworks: cache hit

    func test_searchArtworks_freshCache_returnsCachedWithoutNetwork() async throws {
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: 60, artworks: [Fixtures.artwork(id: 1)]))

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [1])
        XCTAssertTrue(remote.searchedPages.isEmpty, "fresh cache must not trigger a download")
    }

    func test_searchArtworks_freshCache_doesNotTouchTheConnectivityGate() async throws {
        // A fresh cache hit must work fully offline: the monitor is never consulted.
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: 60))
        await monitor.close()

        _ = try await sut.searchArtworks(page: 1)

        let waits = await monitor.waitForConnectionCallCount
        XCTAssertEqual(waits, 0)
    }

    func test_searchArtworks_freshCache_returnsStoredTotalPages() async throws {
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: 60))
        pageStore.stubbedTotalPagesResult = .success(13)

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(page.totalPages, 13)
    }

    func test_searchArtworks_freshCache_totalPagesFetchFails_returnsNilTotalPagesNotError() async throws {
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: 60))
        pageStore.stubbedTotalPagesResult = .failure(MockError.notStubbed)

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertNil(page.totalPages)
        XCTAssertFalse(page.artworks.isEmpty)
    }

    func test_searchArtworks_cachedEmptyPage_isServedAsAValidHit() async throws {
        // Documents the contract: an empty cached page is a hit, not a miss.
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: 60, artworks: []))

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertTrue(page.artworks.isEmpty)
        XCTAssertTrue(remote.searchedPages.isEmpty)
    }

    // MARK: - searchArtworks: freshness boundary

    func test_searchArtworks_cacheOneSecondUnderTTL_isServedFromCache() async throws {
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: Self.ttl - 1))

        _ = try await sut.searchArtworks(page: 1)

        XCTAssertTrue(remote.searchedPages.isEmpty)
    }

    func test_searchArtworks_cacheExactlyAtTTL_isStaleAndRedownloads() async throws {
        // Boundary contract: freshness is age < TTL, so age == TTL is stale.
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: Self.ttl))
        stubNetworkSuccess()

        _ = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(remote.searchedPages, [1])
    }

    // MARK: - searchArtworks: network path

    func test_searchArtworks_noCache_downloadsRequestedPage() async throws {
        stubNetworkSuccess()

        let page = try await sut.searchArtworks(page: 7)

        XCTAssertEqual(remote.searchedPages, [7])
        XCTAssertEqual(page.artworks.map(\.id), [999])
        XCTAssertEqual(page.totalPages, 13)
    }

    func test_searchArtworks_staleCache_redownloadsAndReturnsFreshData() async throws {
        pageStore.stubbedFetchPageResult = .success(cachedPage(ageSeconds: Self.ttl + 100, artworks: [Fixtures.artwork(id: 1)]))
        stubNetworkSuccess()

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [999], "stale cache must be replaced by network data")
    }

    func test_searchArtworks_networkPath_savesDownloadedPage() async throws {
        stubNetworkSuccess()

        _ = try await sut.searchArtworks(page: 3)

        XCTAssertEqual(pageStore.savedPages.count, 1)
        XCTAssertEqual(pageStore.savedPages[0].pageNumber, 3)
        XCTAssertEqual(pageStore.savedPages[0].artworks.map(\.id), [999])
    }

    func test_searchArtworks_cacheReadFails_isTreatedAsMissAndDownloads() async throws {
        // A broken cache must never block data.
        pageStore.stubbedFetchPageResult = .failure(LocalStoreError.fetchFailed(underlying: MockError.notStubbed))
        stubNetworkSuccess()

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(remote.searchedPages, [1])
        XCTAssertEqual(page.artworks.count, 1)
    }

    func test_searchArtworks_savePageFails_stillReturnsDownloadedData() async throws {
        stubNetworkSuccess()
        pageStore.savePageError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [999], "a failed cache write must not fail the request")
    }

    func test_searchArtworks_networkFails_propagatesError() async {
        remote.stubbedSearchResult = .failure(NetworkError.serverError(statusCode: 500))

        do {
            _ = try await sut.searchArtworks(page: 1)
            XCTFail("Expected NetworkError to propagate")
        } catch let error as NetworkError {
            guard case .serverError(let code) = error else {
                return XCTFail("Expected .serverError, got \(error)")
            }
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_searchArtworks_networkFails_nothingIsCached() async {
        remote.stubbedSearchResult = .failure(NetworkError.serverError(statusCode: 500))

        _ = try? await sut.searchArtworks(page: 1)

        XCTAssertTrue(pageStore.savedPages.isEmpty)
        XCTAssertTrue(pageStore.savedTotalPages.isEmpty)
    }

    // MARK: - searchArtworks: totalPages write-once policy

    func test_searchArtworks_firstDownload_storesTotalPages() async throws {
        pageStore.stubbedTotalPagesResult = .success(nil) // nothing stored yet
        stubNetworkSuccess(totalPages: 13)

        _ = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(pageStore.savedTotalPages, [13])
    }

    func test_searchArtworks_totalPagesAlreadyStored_doesNotRewriteIt() async throws {
        pageStore.stubbedTotalPagesResult = .success(13)
        stubNetworkSuccess(totalPages: 14) // server now says 14 — must be ignored

        _ = try await sut.searchArtworks(page: 2)

        XCTAssertTrue(pageStore.savedTotalPages.isEmpty, "totalPages is write-once per cache lifetime")
    }

    func test_searchArtworks_networkPath_returnsLiveTotalPagesEvenWhenStoreHasOld() async throws {
        // The returned value reflects the live response; only the STORED value is frozen.
        pageStore.stubbedTotalPagesResult = .success(13)
        stubNetworkSuccess(totalPages: 14)

        let page = try await sut.searchArtworks(page: 2)

        XCTAssertEqual(page.totalPages, 14)
    }

    func test_searchArtworks_saveTotalPagesFails_stillReturnsData() async throws {
        pageStore.stubbedTotalPagesResult = .success(nil)
        pageStore.saveTotalPagesError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)
        stubNetworkSuccess()

        let page = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.count, 1)
    }

    // MARK: - searchArtworks: parking

    func test_searchArtworks_whenOffline_parksAndCompletesOnReconnection() async throws {
        await monitor.close()
        stubNetworkSuccess()
        let completed = SendableFlag()

        let task = Task { [sut] in
            let page = try await sut!.searchArtworks(page: 1)
            completed.set()
            return page
        }

        // Deterministic: wait until the call has actually reached the gate.
        while await monitor.waitForConnectionCallCount == 0 { await Task.yield() }
        XCTAssertFalse(completed.value, "call must be parked while offline")
        XCTAssertTrue(remote.searchedPages.isEmpty, "no download may start before connectivity")

        await monitor.open()

        let page = try await task.value
        XCTAssertTrue(completed.value)
        XCTAssertEqual(page.artworks.map(\.id), [999])
        XCTAssertEqual(remote.searchedPages, [1], "the parked call executes once reconnected")
    }

    // MARK: - artworkDetail

    func test_artworkDetail_freshCache_returnsCachedWithoutNetwork() async throws {
        detailStore.stubbedFetchDetailResult = .success(
            CachedArtworkDetail(detail: Fixtures.artworkDetail(id: 42), insertedAt: Self.frozenNow.addingTimeInterval(-60))
        )

        let detail = try await sut.artworkDetail(id: 42)

        XCTAssertEqual(detail.id, 42)
        XCTAssertTrue(remote.requestedDetailIds.isEmpty)
    }

    func test_artworkDetail_freshCache_doesNotTouchTheConnectivityGate() async throws {
        detailStore.stubbedFetchDetailResult = .success(
            CachedArtworkDetail(detail: Fixtures.artworkDetail(id: 42), insertedAt: Self.frozenNow.addingTimeInterval(-60))
        )
        await monitor.close()

        _ = try await sut.artworkDetail(id: 42)

        let waits = await monitor.waitForConnectionCallCount
        XCTAssertEqual(waits, 0)
    }

    func test_artworkDetail_staleCache_redownloadsAndSaves() async throws {
        detailStore.stubbedFetchDetailResult = .success(
            CachedArtworkDetail(detail: Fixtures.artworkDetail(id: 42, title: "Old"), insertedAt: Self.frozenNow.addingTimeInterval(-Self.ttl))
        )
        remote.stubbedDetailResult = .success(Fixtures.artworkDetail(id: 42, title: "Fresh"))

        let detail = try await sut.artworkDetail(id: 42)

        XCTAssertEqual(detail.title, "Fresh")
        XCTAssertEqual(remote.requestedDetailIds, [42])
        XCTAssertEqual(detailStore.savedDetails.map(\.id), [42])
    }

    func test_artworkDetail_noCache_downloadsRequestedId() async throws {
        remote.stubbedDetailResult = .success(Fixtures.artworkDetail(id: 7))

        let detail = try await sut.artworkDetail(id: 7)

        XCTAssertEqual(detail.id, 7)
        XCTAssertEqual(remote.requestedDetailIds, [7])
    }

    func test_artworkDetail_cacheReadFails_isTreatedAsMiss() async throws {
        detailStore.stubbedFetchDetailResult = .failure(LocalStoreError.fetchFailed(underlying: MockError.notStubbed))
        remote.stubbedDetailResult = .success(Fixtures.artworkDetail(id: 7))

        let detail = try await sut.artworkDetail(id: 7)

        XCTAssertEqual(detail.id, 7)
    }

    func test_artworkDetail_saveFails_stillReturnsDownloadedDetail() async throws {
        remote.stubbedDetailResult = .success(Fixtures.artworkDetail(id: 7))
        detailStore.saveDetailError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)

        let detail = try await sut.artworkDetail(id: 7)

        XCTAssertEqual(detail.id, 7)
    }

    func test_artworkDetail_networkFails_propagatesError() async {
        remote.stubbedDetailResult = .failure(NetworkError.transport(URLError(.timedOut)))

        do {
            _ = try await sut.artworkDetail(id: 7)
            XCTFail("Expected NetworkError to propagate")
        } catch let error as NetworkError {
            guard case .transport = error else {
                return XCTFail("Expected .transport, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    // MARK: - totalPages accessor

    func test_totalPages_returnsStoredValue() async {
        pageStore.stubbedTotalPagesResult = .success(13)
        let value = await sut.totalPages()
        XCTAssertEqual(value, 13)
    }

    func test_totalPages_whenNothingStored_returnsNil() async {
        pageStore.stubbedTotalPagesResult = .success(nil)
        let value = await sut.totalPages()
        XCTAssertNil(value)
    }

    func test_totalPages_whenStoreThrows_returnsNil() async {
        pageStore.stubbedTotalPagesResult = .failure(MockError.notStubbed)
        let value = await sut.totalPages()
        XCTAssertNil(value)
    }

    // MARK: - clearCache

    func test_clearCache_deletesPagesAndDetails() async throws {
        try await sut.clearCache()

        XCTAssertEqual(pageStore.deleteAllPagesCallCount, 1)
        XCTAssertEqual(detailStore.deleteAllDetailsCallCount, 1)
    }

    func test_clearCache_pagesDeletionFails_propagatesAndSkipsDetails() async {
        // Documents the sequential contract: a pages failure stops the operation.
        pageStore.deleteAllPagesError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)

        do {
            try await sut.clearCache()
            XCTFail("Expected LocalStoreError to propagate")
        } catch is LocalStoreError {
            XCTAssertEqual(detailStore.deleteAllDetailsCallCount, 0)
        } catch {
            XCTFail("Expected LocalStoreError, got \(error)")
        }
    }

    func test_clearCache_detailsDeletionFails_propagates() async {
        detailStore.deleteAllDetailsError = LocalStoreError.saveFailed(underlying: MockError.notStubbed)

        do {
            try await sut.clearCache()
            XCTFail("Expected LocalStoreError to propagate")
        } catch is LocalStoreError {
            XCTAssertEqual(pageStore.deleteAllPagesCallCount, 1, "pages deletion ran before the failure")
        } catch {
            XCTFail("Expected LocalStoreError, got \(error)")
        }
    }

    // MARK: - Memory

    func test_repository_deallocates_noMemoryLeak() {
        var repository: CachedArtworkRepository? = CachedArtworkRepository(
            remote: MockArtworkRemoteRepository(),
            pageStore: MockSearchResultsLocalStore(),
            detailStore: MockArtworkDetailLocalStore(),
            networkMonitor: MockNetworkMonitor()
        )
        weak var weakReference = repository

        repository = nil

        XCTAssertNil(weakReference, "Potential memory leak: CachedArtworkRepository not deallocated")
    }
}
