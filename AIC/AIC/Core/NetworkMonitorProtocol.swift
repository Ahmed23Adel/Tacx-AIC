//
//  NetworkMonitorProtocol.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

/// Connectivity gate for deferred execution: callers that need the network
/// await this before making a request. When online it returns immediately;
/// when offline the call suspends ("parks") and resumes on reconnection.
nonisolated protocol NetworkMonitorProtocol: Sendable {
    func waitForConnection() async

    /// Stream of connectivity changes for UI state (e.g. an offline banner).
    /// Emits the current state immediately on subscription, then every change.
    /// Observational only — data requests must NOT be gated on it; the
    /// cache-policy layer decides when the network is needed.
    func connectionUpdates() async -> AsyncStream<Bool>
}
