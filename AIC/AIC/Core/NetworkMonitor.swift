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
        // Parked callers cannot exist here: an in-flight waitForConnection call
        // retains this actor, so deinit is unreachable while anything is parked.
        // Observer streams CAN outlive the monitor (a stream doesn't retain its
        // source) — finish them so consumers' for-await loops end instead of
        // hanging forever.
        observers.values.forEach { $0.finish() }
    }

    func waitForConnection() async {
        guard !isConnected else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // No re-check of isConnected needed: this actor holds continuously
                // from the guard above through this synchronous continuation body
                // (withCheckedContinuation runs it before actually suspending), so
                // update(isConnected:) cannot interleave and flip the value here.
                waiters[id] = continuation
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
        continuation.yield(isConnected)
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    // Internal (not private): test seam so parking assertions can wait
    // deterministically for a caller to register instead of polling yields.
    var parkedWaiterCount: Int { waiters.count }

    
    func update(isConnected: Bool) {
        guard isConnected != self.isConnected else { return }
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
