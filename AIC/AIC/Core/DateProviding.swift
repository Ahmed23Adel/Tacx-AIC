//
//  DateProviding.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

/// Abstraction over "now" so cache timestamps are deterministic in tests.
/// nonisolated: usable from any actor (the app module defaults to MainActor isolation).
nonisolated protocol DateProviding: Sendable {
    var now: Date { get }
}

nonisolated struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
}
