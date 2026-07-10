//
//  NetworkMonitorLivePathIntegrationTests.swift
//  AICTests
//
//  Exercises the real NWPathMonitor wiring (init callback registration and the
//  OS-delivered initial path update) — the one part of NetworkMonitor that unit
//  tests deliberately bypass via startsPathMonitor: false.
//
//  Requires an active network path on the host, same as LiveAPIIntegrationTests;
//  skipped via SKIP_LIVE_TESTS=1.
//

import XCTest
@testable import AIC

final class NetworkMonitorLivePathIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SKIP_LIVE_TESTS"] == "1",
            "Live path tests skipped via SKIP_LIVE_TESTS"
        )
    }

    func test_realPathMonitor_initialUpdate_unparksWaiter() async throws {
        let monitor = NetworkMonitor() // real NWPathMonitor starts
        let completed = SendableFlag()

        let parkedCall = Task {
            await monitor.waitForConnection()
            completed.set()
        }

        // The OS delivers the initial path update within milliseconds of start;
        // on a networked host it is .satisfied and must release the waiter.
        let deadline = Date().addingTimeInterval(5)
        while !completed.value, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertTrue(completed.value, "initial NWPath update should unpark the call (needs an online host)")
        await parkedCall.value
    }
}
