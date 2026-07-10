//
//  FixedDateProvider.swift
//  AICTests
//
//  A clock frozen at whatever instant the test chooses, making cache
//  timestamps deterministic and assertable with exact equality.
//

import Foundation
@testable import AIC

nonisolated struct FixedDateProvider: DateProviding {
    let now: Date
}
