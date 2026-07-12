//
//  CachedArtworkRepositoryIntegrationTests.swift
//  AICTests
//
//  Full-stack integration for the cache-policy layer: a REAL
//  SwiftDataArtworkLocalStore (in-memory), a REAL ArtworkRepository +
//  AlamofireAPIRequester (stubbed only at the wire via MockURLProtocol),
//  and a REAL NetworkMonitor (driven deterministically via update(isConnected:)).
//
//  CachedArtworkRepositoryTests (unit) proves the policy's decisions in
//  isolation with four mocks. This suite proves those decisions still hold
//  when the real collaborators are wired together: real persistence timing,
//  real JSON decoding through the real Alamofire pipeline, and real
//  connectivity parking — none of which a mock can misrepresent.
//

import XCTest
import Alamofire
import SwiftData
@testable import AIC

final class CachedArtworkRepositoryIntegrationTests: XCTestCase {

    private static let baseURL = URL(string: "https://integration-test.invalid/api/v1")!
    private static let ttl = AppConstants.Cache.timeToLive
    private static let t0 = Date(timeIntervalSince1970: 1_750_000_000)

    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        // force try: an in-memory container has no external dependency that
        // can fail; a real failure here would mean the test environment itself
        // is broken, not the code under test.
        container = try! ArtworkCacheContainerFactory.make(inMemoryOnly: true)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        container = nil
        super.tearDown()
    }

    // MARK: - SUT factory

    /// Builds a repository backed by the shared in-memory container, frozen
    /// at `now`. Building a second SUT at a later `now` against the SAME
    /// container simulates time passing over real persisted data.
    private func makeSUT(now: Date, startsPathMonitor: Bool = false) -> (repository: CachedArtworkRepository, monitor: NetworkMonitor) {
        let localStore = SwiftDataArtworkLocalStore(modelContainer: container, dateProvider: FixedDateProvider(now: now))
        let requester = AlamofireAPIRequester(baseURL: Self.baseURL, session: .stubbed())
        let remote = ArtworkRepository(apiRequester: requester)
        let monitor = NetworkMonitor(startsPathMonitor: startsPathMonitor)
        let repository = CachedArtworkRepository(
            remote: remote,
            pageStore: localStore,
            detailStore: localStore,
            networkMonitor: monitor,
            dateProvider: FixedDateProvider(now: now),
            timeToLive: Self.ttl
        )
        return (repository, monitor)
    }

    // MARK: - JSON builders (real API response shapes)

    private func searchJSON(page: Int, ids: [Int], totalPages: Int = 13) -> Data {
        let items = ids.map {
            #"{"id": \#($0), "title": "Artwork \#($0)", "image_id": "img-\#($0)", "date_display": "1630"}"#
        }.joined(separator: ",")
        let json = """
        {"pagination": {"total": 247, "limit": 20, "offset": 0, "total_pages": \(totalPages), "current_page": \(page)}, \
        "data": [\(items)]}
        """
        return Data(json.utf8)
    }

    private func detailJSON(id: Int, title: String) -> Data {
        let json = """
        {"data": {"id": \(id), "title": "\(title)", "artist_display": "Rembrandt van Rijn", \
        "date_display": "1630", "medium_display": "Oil on canvas", "dimensions": "10 x 10 cm", \
        "place_of_origin": "Holland", "credit_line": "Gift", "image_id": "img-\(id)", \
        "short_description": null, "description": null}}
        """
        return Data(json.utf8)
    }

    // MARK: - Network stubbing helpers

    private func stubNetwork(data: Data, statusCode: Int = 200, recorder: NetworkCallRecorder? = nil) {
        MockURLProtocol.requestHandler = { request in
            recorder?.record()
            // force unwrap OK: request.url is always set for requests Alamofire builds
            return (HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, data)
        }
    }

    /// Records the attempt (so a test can assert it never happened) instead
    /// of actually reaching the network.
    private func stubNetworkMustNotBeCalled(recorder: NetworkCallRecorder) {
        MockURLProtocol.requestHandler = { _ in
            recorder.record()
            throw URLError(.notConnectedToInternet)
        }
    }

    // MARK: - Cache-first: real download then real cache hit

    func test_searchArtworks_noCache_downloadsThroughRealStackAndPersists() async throws {
        let (repository, _) = makeSUT(now: Self.t0)
        let recorder = NetworkCallRecorder()
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]), recorder: recorder)

        let page = try await repository.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [1, 2])
        XCTAssertEqual(page.totalPages, 13)
        XCTAssertEqual(recorder.count, 1)
    }

    func test_searchArtworks_secondCallWithinTTL_servesFromRealCache_neverTouchesNetwork() async throws {
        let (firstCall, _) = makeSUT(now: Self.t0)
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]))
        _ = try await firstCall.searchArtworks(page: 1)

        // Same container, 1 minute later — still well within the 5-minute TTL.
        let (secondCall, _) = makeSUT(now: Self.t0.addingTimeInterval(60))
        let recorder = NetworkCallRecorder()
        stubNetworkMustNotBeCalled(recorder: recorder)

        let page = try await secondCall.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [1, 2], "must be served from the real persisted cache")
        XCTAssertEqual(recorder.count, 0, "a fresh cache hit must never reach the network")
    }

    func test_searchArtworks_afterTTLExpires_realCacheIsStale_redownloadsAndReplaces() async throws {
        let (firstCall, _) = makeSUT(now: Self.t0)
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]))
        _ = try await firstCall.searchArtworks(page: 1)

        // Same container, one second past the 5-minute TTL boundary.
        let (secondCall, _) = makeSUT(now: Self.t0.addingTimeInterval(Self.ttl + 1))
        let recorder = NetworkCallRecorder()
        stubNetwork(data: searchJSON(page: 1, ids: [9, 10]), recorder: recorder)

        let page = try await secondCall.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [9, 10], "stale cache must be replaced by the fresh download")
        XCTAssertEqual(recorder.count, 1)
    }

    // MARK: - Page-level cache: a stale page must not evict a fresh neighbour

    func test_searchArtworks_stalePage_doesNotEvictADifferentFreshPage() async throws {
        let (loadPage1, _) = makeSUT(now: Self.t0)
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]))
        _ = try await loadPage1.searchArtworks(page: 1)

        // Page 2 saved 4 minutes later — still fresh when page 1 expires.
        let (loadPage2, _) = makeSUT(now: Self.t0.addingTimeInterval(240))
        stubNetwork(data: searchJSON(page: 2, ids: [3, 4]))
        _ = try await loadPage2.searchArtworks(page: 2)

        // Now: page 1 is stale (age > TTL), page 2 is still fresh (age < TTL).
        let checkpoint = Self.t0.addingTimeInterval(Self.ttl + 10)
        let (recheck, _) = makeSUT(now: checkpoint)

        let page1Recorder = NetworkCallRecorder()
        stubNetwork(data: searchJSON(page: 1, ids: [5, 6]), recorder: page1Recorder)
        let page1 = try await recheck.searchArtworks(page: 1)
        XCTAssertEqual(page1.artworks.map(\.id), [5, 6], "stale page 1 must redownload")
        XCTAssertEqual(page1Recorder.count, 1)

        let page2Recorder = NetworkCallRecorder()
        stubNetworkMustNotBeCalled(recorder: page2Recorder)
        let page2 = try await recheck.searchArtworks(page: 2)
        XCTAssertEqual(page2.artworks.map(\.id), [3, 4], "fresh page 2 must be untouched by page 1's expiry")
        XCTAssertEqual(page2Recorder.count, 0)
    }

    // MARK: - Offline parking, with a REAL NetworkMonitor

    func test_searchArtworks_offlineWithNoCache_parksOnRealMonitor_completesOnReconnect() async throws {
        let (repository, monitor) = makeSUT(now: Self.t0)
        await monitor.update(isConnected: false)
        let recorder = NetworkCallRecorder()
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]), recorder: recorder)

        let task = Task { try await repository.searchArtworks(page: 1) }

        while await monitor.parkedWaiterCount == 0 { await Task.yield() }
        XCTAssertEqual(recorder.count, 0, "must not download before connectivity returns")

        await monitor.update(isConnected: true)
        let page = try await task.value

        XCTAssertEqual(page.artworks.map(\.id), [1, 2])
        XCTAssertEqual(recorder.count, 1, "the parked call must execute exactly once, after reconnecting")
    }

    func test_searchArtworks_offlineWithValidRealCache_servedImmediately_neverParks() async throws {
        let (loadOnline, _) = makeSUT(now: Self.t0)
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]))
        _ = try await loadOnline.searchArtworks(page: 1)

        let (repository, monitor) = makeSUT(now: Self.t0.addingTimeInterval(30))
        await monitor.update(isConnected: false)
        let recorder = NetworkCallRecorder()
        stubNetworkMustNotBeCalled(recorder: recorder)

        let page = try await repository.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [1, 2])
        XCTAssertEqual(recorder.count, 0)
        let parked = await monitor.parkedWaiterCount
        XCTAssertEqual(parked, 0, "a fresh cache hit must never reach the connectivity gate")
    }

    // MARK: - Pull-to-refresh: clearCache wipes the REAL store

    func test_clearCache_wipesRealPersistedPagesAndDetails_forcesFreshRedownload() async throws {
        let (setup, _) = makeSUT(now: Self.t0)
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]))
        _ = try await setup.searchArtworks(page: 1)
        stubNetwork(data: detailJSON(id: 1, title: "Old Title"))
        _ = try await setup.artworkDetail(id: 1)

        try await setup.clearCache()

        // Moments later — well within TTL, so only an empty real cache
        // explains a redownload being required.
        let (afterClear, _) = makeSUT(now: Self.t0.addingTimeInterval(5))
        let recorder = NetworkCallRecorder()
        stubNetwork(data: searchJSON(page: 1, ids: [7, 8]), recorder: recorder)

        let page = try await afterClear.searchArtworks(page: 1)

        XCTAssertEqual(page.artworks.map(\.id), [7, 8])
        XCTAssertEqual(recorder.count, 1, "clearCache must have actually removed the persisted row")
    }

    // MARK: - Per-artwork refresh: scoped deletion in the REAL store

    func test_refreshArtworkDetail_onlyReplacesThatArtwork_othersStayCachedInRealStore() async throws {
        let (setup, _) = makeSUT(now: Self.t0)
        stubNetwork(data: detailJSON(id: 1, title: "Artwork One"))
        _ = try await setup.artworkDetail(id: 1)
        stubNetwork(data: detailJSON(id: 2, title: "Artwork Two"))
        _ = try await setup.artworkDetail(id: 2)

        let (refresh, _) = makeSUT(now: Self.t0.addingTimeInterval(10))
        stubNetwork(data: detailJSON(id: 1, title: "Artwork One — Refreshed"))
        let refreshed = try await refresh.refreshArtworkDetail(id: 1)
        XCTAssertEqual(refreshed.title, "Artwork One — Refreshed")

        // Artwork 2 must still be the original, fresh, real cached copy —
        // proven by making the network unreachable and reading it back.
        let (readArtworkTwo, _) = makeSUT(now: Self.t0.addingTimeInterval(11))
        let recorder = NetworkCallRecorder()
        stubNetworkMustNotBeCalled(recorder: recorder)
        let untouched = try await readArtworkTwo.artworkDetail(id: 2)

        XCTAssertEqual(untouched.title, "Artwork Two")
        XCTAssertEqual(recorder.count, 0)
    }

    // MARK: - totalPages: write-once per real cache lifetime

    func test_totalPages_persistedOnFirstDownload_thenFrozenDespiteServerChange() async throws {
        let (first, _) = makeSUT(now: Self.t0)
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2], totalPages: 13))
        _ = try await first.searchArtworks(page: 1)

        // Server now reports 14 pages, but totalPages was already learned
        // this cache lifetime — the stored value must not move.
        let (second, _) = makeSUT(now: Self.t0.addingTimeInterval(Self.ttl + 1))
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2], totalPages: 14))
        let page = try await second.searchArtworks(page: 1)

        XCTAssertEqual(page.totalPages, 14, "the RETURNED value still reflects the live response")
        let stored = await second.totalPages()
        XCTAssertEqual(stored, 13, "the STORED value is write-once per cache lifetime")
    }

    // MARK: - Real error propagation through the full stack

    func test_searchArtworks_realServerError_propagatesAsNetworkError() async {
        let (repository, _) = makeSUT(now: Self.t0)
        MockURLProtocol.requestHandler = { request in
            // force unwrap OK: request.url is always set for requests Alamofire builds
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await repository.searchArtworks(page: 1)
            XCTFail("Expected NetworkError to propagate through the real stack")
        } catch let error as NetworkError {
            guard case .serverError(let statusCode) = error else {
                return XCTFail("Expected .serverError, got \(error)")
            }
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_searchArtworks_networkErrorOnFirstLoad_leavesRealCacheEmpty() async {
        let (repository, _) = makeSUT(now: Self.t0)
        MockURLProtocol.requestHandler = { request in
            // force unwrap OK: request.url is always set for requests Alamofire builds
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        _ = try? await repository.searchArtworks(page: 1)

        // A later, working request must still see an empty cache (nothing
        // partial was persisted from the failed attempt).
        let (retry, _) = makeSUT(now: Self.t0.addingTimeInterval(1))
        let recorder = NetworkCallRecorder()
        stubNetwork(data: searchJSON(page: 1, ids: [1, 2]), recorder: recorder)
        _ = try? await retry.searchArtworks(page: 1)

        XCTAssertEqual(recorder.count, 1, "a failed download must not have left a cached entry behind")
    }
}

/// Thread-safe call counter for stub handlers invoked off the test's own context.
private final class NetworkCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func record() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
}
