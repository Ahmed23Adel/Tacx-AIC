//
//  NetworkMonitor.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import Network
import os

actor NetworkMonitor: NetworkMonitorProtocol {
    private let monitor = NWPathMonitor()
    private var isConnected = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var observers: [UUID: AsyncStream<Bool>.Continuation] = [:]

    /// - Parameter startsPathMonitor: pass false in tests so the real
    ///   NWPathMonitor never runs and update(isConnected:) has a single,
    ///   deterministic caller — the test itself.
    init(startsPathMonitor: Bool = true) {
        guard startsPathMonitor else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { await self?.update(isConnected: connected) }
        }
        monitor.start(queue: DispatchQueue(label: "com.aic.networkmonitor"))
    }

    deinit {
        monitor.cancel()
        observers.values.forEach { $0.finish() }
    }

    func waitForConnection() async {
        guard !isConnected else { return }
        let id = UUID()
        AppLogger.connectivity.notice("call parking (offline) — \(self.waiters.count + 1, privacy: .public) waiter(s) after this one")
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiters[id] = continuation
            }
        } onCancel: {
            AppLogger.connectivity.notice("parked call cancelled — releasing waiter")
            Task { await self.removeWaiter(id) }
        }
    }

    func connectionUpdates() async -> AsyncStream<Bool> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        continuation.yield(isConnected)
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    var parkedWaiterCount: Int { waiters.count }

    func update(isConnected: Bool) {
        guard isConnected != self.isConnected else { return }
        self.isConnected = isConnected
        AppLogger.connectivity.notice("connectivity changed -> \(isConnected ? "ONLINE" : "OFFLINE", privacy: .public)")
        observers.values.forEach { $0.yield(isConnected) }

        guard isConnected else { return }
        if !waiters.isEmpty {
            AppLogger.connectivity.notice("resuming \(self.waiters.count, privacy: .public) parked call(s)")
        }
        waiters.values.forEach { $0.resume() }
        waiters.removeAll()
    }

    private func removeWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume()
    }

    private func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }
}
