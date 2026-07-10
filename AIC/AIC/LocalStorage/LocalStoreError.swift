//
//  LocalStoreError.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

/// The local storage layer's error vocabulary. SwiftData errors are translated
/// into these at the store boundary, mirroring how the networking layer stops
/// AFError at its border — no persistence-framework types leak upward.
enum LocalStoreError: LocalizedError {
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return String(localized: "Saved data could not be read.")
        case .saveFailed:
            return String(localized: "Data could not be saved on this device.")
        }
    }
}
