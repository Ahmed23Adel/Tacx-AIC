//
//  NetworkMonitor.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import Network

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
        // Never strand a parked call: if the monitor dies while callers are
        // suspended, release them rather than leaking their tasks forever.
        waiters.values.forEach { $0.resume() }
        observers.values.forEach { $0.finish() }
    }

    func waitForConnection() async {
        guard !isConnected else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Re-check: connectivity may have arrived between the guard and here.
                if isConnected {
                    continuation.resume()
                } else {
                    waiters[id] = continuation
                }
            }
        } onCancel: {
            // Resume the waiter so the parked task can exit; the network call
            // it proceeds to will fail fast with a cancellation error.
            Task { await self.removeWaiter(id) }
        }
    }

    func connectionUpdates() async -> AsyncStream<Bool> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        continuation.yield(isConnected) // late subscribers still learn the current state
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    // Internal (not private): the testable seam. Production's only caller is
    // the NWPathMonitor callback; tests drive connectivity transitions directly.
    func update(isConnected: Bool) {
        guard isConnected != self.isConnected else { return } // NWPathMonitor can repeat states
        self.isConnected = isConnected
        observers.values.forEach { $0.yield(isConnected) }

        guard isConnected else { return }
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
