//
//  ViewModelSearchArtworksFullStackIntegrationTests.swift
//  AICTests
//
//  Wires ViewModelSearchArtworks to a REAL CachedArtworkRepository, a REAL
//  SwiftDataArtworkLocalStore (in-memory), a REAL Alamofire stack (stubbed
//  only at the wire), and a REAL NetworkMonitor. ViewModelSearchArtworksTests
//  (unit) proves the view model's own logic against a mock repository; this
//  suite proves the view model correctly drives the real stack underneath it,
//  end to end from a tap-equivalent call down to persisted bytes.
//

import XCTest
import Alamofire
import SwiftData
@testable import AIC

final class ViewModelSearchArtworksFullStackIntegrationTests: XCTestCase {

    private static let baseURL = URL(string: "https://vm-integration-test.invalid/api/v1")!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        // force try: an in-memory container has no external dependency that
        // can fail; a real failure here means the test environment is broken.
        container = try! ArtworkCacheContainerFactory.make(inMemoryOnly: true)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        container = nil
        super.tearDown()
    }

    private func makeSUT(startsPathMonitor: Bool = false) -> (viewModel: ViewModelSearchArtworks, monitor: NetworkMonitor) {
        let localStore = SwiftDataArtworkLocalStore(modelContainer: container)
        let requester = AlamofireAPIRequester(baseURL: Self.baseURL, session: .stubbed())
        let remote = ArtworkRepository(apiRequester: requester)
        let monitor = NetworkMonitor(startsPathMonitor: startsPathMonitor)
        let repository = CachedArtworkRepository(
            remote: remote, pageStore: localStore, detailStore: localStore, networkMonitor: monitor
        )
        let viewModel = ViewModelSearchArtworks(repository: repository, networkMonitor: monitor)
        return (viewModel, monitor)
    }

    private func searchJSON(page: Int, ids: [Int], totalPages: Int = 13) -> Data {
        let items = ids.map {
            #"{"id": \#($0), "title": "Artwork \#($0)", "image_id": null, "date_display": "1630"}"#
        }.joined(separator: ",")
        let json = """
        {"pagination": {"total": 247, "limit": 20, "offset": 0, "total_pages": \(totalPages), "current_page": \(page)}, \
        "data": [\(items)]}
        """
        return Data(json.utf8)
    }

    private func stub(data: Data, statusCode: Int = 200) {
        MockURLProtocol.requestHandler = { request in
            // force unwrap OK: request.url is always set for requests Alamofire builds
            (HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, data)
        }
    }

    // MARK: - Initial load through the real stack

    func test_onAppear_online_populatesArtworksThroughRealStack() async {
        let (viewModel, _) = makeSUT()
        stub(data: searchJSON(page: 1, ids: [1, 2, 3]))

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.artworks.map(\.id), [1, 2, 3])
        XCTAssertEqual(viewModel.totalPages, 13)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Offline, driven by a REAL NetworkMonitor

    func test_onAppear_offlineWithNoCache_showsWaitingForConnection_thenLoadsOnReconnect() async {
        let (viewModel, monitor) = makeSUT()
        await monitor.update(isConnected: false)
        await viewModel.observeConnectivity()
        stub(data: searchJSON(page: 1, ids: [1, 2]))

        let loadTask = Task { await viewModel.onAppear() }

        while await monitor.parkedWaiterCount == 0 { await Task.yield() }
        XCTAssertTrue(viewModel.showsWaitingForConnection)
        XCTAssertTrue(viewModel.artworks.isEmpty)

        await monitor.update(isConnected: true)
        await loadTask.value

        XCTAssertEqual(viewModel.artworks.map(\.id), [1, 2])
        XCTAssertFalse(viewModel.showsWaitingForConnection)
    }

    // MARK: - Pull-to-refresh through the real stack

    func test_refresh_wipesRealCacheAndReloadsFreshDataFromNetwork() async {
        let (viewModel, _) = makeSUT()
        stub(data: searchJSON(page: 1, ids: [1, 2]))
        await viewModel.onAppear()
        XCTAssertEqual(viewModel.artworks.map(\.id), [1, 2])

        stub(data: searchJSON(page: 1, ids: [9, 8, 7]))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.artworks.map(\.id), [9, 8, 7], "refresh must replace, not append, real content")
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Infinite scroll triggers a real second download

    func test_onRowAppear_nearEnd_downloadsPage2ThroughRealStackAndAppends() async {
        let (viewModel, _) = makeSUT()
        stub(data: searchJSON(page: 1, ids: Array(1...20)))
        await viewModel.onAppear()

        stub(data: searchJSON(page: 2, ids: Array(21...40)))
        await viewModel.onRowAppear(viewModel.artworks[15]) // within the 5-row prefetch distance

        XCTAssertEqual(viewModel.artworks.count, 40)
        XCTAssertEqual(viewModel.artworks.map(\.id), Array(1...40))
    }
}
