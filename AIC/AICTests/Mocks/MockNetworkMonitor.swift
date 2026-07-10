//
//  MockNetworkMonitor.swift
//  AICTests
//
//  A controllable connectivity gate: open (default) lets calls through
//  immediately; closed parks them until open() — mirroring the real
//  NetworkMonitor's contract without any OS involvement.
//

import Foundation
@testable import AIC

actor MockNetworkMonitor: NetworkMonitorProtocol {
    private(set) var waitForConnectionCallCount = 0
    private var isOpen = true
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var parkedCount: Int { waiters.count }

    func close() {
        isOpen = false
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func waitForConnection() async {
        waitForConnectionCallCount += 1
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func connectionUpdates() async -> AsyncStream<Bool> {
        let current = isOpen
        return AsyncStream { continuation in
            continuation.yield(current)
            continuation.finish()
        }
    }
}
