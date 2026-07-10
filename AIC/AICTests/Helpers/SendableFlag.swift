//
//  SendableFlag.swift
//  AICTests
//
//  Thread-safe boolean box for asserting whether a concurrent task has
//  completed — the "did the parked call resume?" primitive.
//

import Foundation

final class SendableFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set() {
        lock.lock()
        defer { lock.unlock() }
        _value = true
    }
}
