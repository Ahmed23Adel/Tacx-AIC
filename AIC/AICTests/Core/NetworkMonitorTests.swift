//
//  NetworkMonitorTests.swift
//  AICTests
//
//  The parking state machine, driven deterministically: constructed with
//  startsPathMonitor: false so the test is the only writer, playing the role
//  of the operating system via update(isConnected:).
//
//  COVERAGE NOTE: the NWPathMonitor wiring in init (callback registration and
//  queue start) is the OS shell and cannot run under test control — the
//  bounded, deliberate gap of this suite.
//

import XCTest
@testable import AIC

final class NetworkMonitorTests: XCTestCase {

    private var sut: NetworkMonitor!

    override func setUp() {
        super.setUp()
        sut = NetworkMonitor(startsPathMonitor: false)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Deterministically waits until `count` callers are parked at the gate.
    private func waitForParkedWaiters(_ count: Int) async {
        while await sut.parkedWaiterCount < count { await Task.yield() }
    }

    // MARK: - waitForConnection

    func test_waitForConnection_whenConnected_returnsImmediately() async {
        await sut.update(isConnected: true)

        await sut.waitForConnection() // must not hang — completing IS the assertion

        let parked = await sut.parkedWaiterCount
        XCTAssertEqual(parked, 0)
    }

    func test_waitForConnection_whenOffline_parksUntilConnectivityReturns() async {
        // The assignment's core offline requirement, verified end to end.
        let resumed = SendableFlag()

        let parkedCall = Task { [sut] in
            await sut!.waitForConnection()
            resumed.set()
        }

        await waitForParkedWaiters(1)
        XCTAssertFalse(resumed.value, "call must stay parked while offline")

        await sut.update(isConnected: true)
        await parkedCall.value

        XCTAssertTrue(resumed.value, "parked call must execute once connection is available")
    }

    func test_waitForConnection_multipleParkedCallers_allResumeOnOneReconnection() async {
        let flags = (0..<5).map { _ in SendableFlag() }

        let tasks = flags.map { flag in
            Task { [sut] in
                await sut!.waitForConnection()
                flag.set()
            }
        }

        await waitForParkedWaiters(5)
        XCTAssertTrue(flags.allSatisfy { !$0.value })

        await sut.update(isConnected: true)
        for task in tasks { await task.value }

        XCTAssertTrue(flags.allSatisfy(\.value), "one reconnection must release every parked call")
    }

    func test_waitForConnection_cancelledWhilstParked_isReleasedWithoutConnectivity() async {
        let finished = SendableFlag()

        let parkedCall = Task { [sut] in
            await sut!.waitForConnection()
            finished.set()
        }
        await waitForParkedWaiters(1)

        parkedCall.cancel()
        await parkedCall.value

        XCTAssertTrue(finished.value, "cancellation must release the parked call")
        let parked = await sut.parkedWaiterCount
        XCTAssertEqual(parked, 0, "cancelled waiter must be deregistered, not leaked")
    }

    func test_waitForConnection_afterDisconnection_parksAgain() async {
        await sut.update(isConnected: true)
        await sut.update(isConnected: false)

        let resumed = SendableFlag()
        let parkedCall = Task { [sut] in
            await sut!.waitForConnection()
            resumed.set()
        }

        await waitForParkedWaiters(1)
        XCTAssertFalse(resumed.value, "going offline again must re-enable parking")

        await sut.update(isConnected: true)
        await parkedCall.value
        XCTAssertTrue(resumed.value)
    }

    // MARK: - connectionUpdates

    func test_connectionUpdates_emitsCurrentStateImmediately() async {
        // A subscriber must learn the present state without waiting for a change.
        var iterator = await sut.connectionUpdates().makeAsyncIterator()

        let first = await iterator.next()

        XCTAssertEqual(first, false, "initial state is disconnected until the OS reports otherwise")
    }

    func test_connectionUpdates_lateSubscriber_seesCurrentStateNotHistory() async {
        await sut.update(isConnected: true)

        var iterator = await sut.connectionUpdates().makeAsyncIterator()
        let first = await iterator.next()

        XCTAssertEqual(first, true)
    }

    func test_connectionUpdates_emitsTransitionsInOrder() async {
        var iterator = await sut.connectionUpdates().makeAsyncIterator()
        _ = await iterator.next() // consume initial false

        await sut.update(isConnected: true)
        await sut.update(isConnected: false)

        let first = await iterator.next()
        let second = await iterator.next()

        XCTAssertEqual(first, true)
        XCTAssertEqual(second, false)
    }

    func test_connectionUpdates_repeatedSameState_isDeduplicated() async {
        // NWPathMonitor can re-report the same status; observers must only
        // hear actual transitions (no UI flicker).
        var iterator = await sut.connectionUpdates().makeAsyncIterator()
        _ = await iterator.next() // initial false

        await sut.update(isConnected: false) // repeat — must NOT emit
        await sut.update(isConnected: true)  // transition — must emit

        let next = await iterator.next()

        XCTAssertEqual(next, true, "the repeated 'false' must be swallowed; next emission is the true transition")
    }

    func test_connectionUpdates_supportsMultipleIndependentSubscribers() async {
        var first = await sut.connectionUpdates().makeAsyncIterator()
        var second = await sut.connectionUpdates().makeAsyncIterator()
        _ = await first.next()
        _ = await second.next()

        await sut.update(isConnected: true)

        let fromFirst = await first.next()
        let fromSecond = await second.next()

        XCTAssertEqual(fromFirst, true)
        XCTAssertEqual(fromSecond, true)
    }

    // MARK: - update dedupe interaction with parking

    func test_update_repeatedOffline_doesNotDisturbParkedWaiters() async {
        let resumed = SendableFlag()
        let parkedCall = Task { [sut] in
            await sut!.waitForConnection()
            resumed.set()
        }
        await waitForParkedWaiters(1)

        await sut.update(isConnected: false) // repeated state — waiter must stay parked
        XCTAssertFalse(resumed.value)

        await sut.update(isConnected: true)
        await parkedCall.value
        XCTAssertTrue(resumed.value)
    }

    // MARK: - deinit

    func test_deinit_finishesActiveObserverStreams() async {
        // A stream does not retain its source, so a monitor can die while
        // observers iterate. Their loops must END (nil), not hang forever.
        var monitor: NetworkMonitor? = NetworkMonitor(startsPathMonitor: false)
        var iterator = await monitor!.connectionUpdates().makeAsyncIterator()
        _ = await iterator.next() // consume the initial emission

        monitor = nil // deinit fires

        let next = await iterator.next()
        XCTAssertNil(next, "deinit must finish observer streams")
    }

    // MARK: - Memory

    func test_monitor_deallocates_noMemoryLeak() {
        var monitor: NetworkMonitor? = NetworkMonitor(startsPathMonitor: false)
        weak var weakReference = monitor

        monitor = nil

        XCTAssertNil(weakReference, "Potential memory leak: NetworkMonitor not deallocated")
    }
}
