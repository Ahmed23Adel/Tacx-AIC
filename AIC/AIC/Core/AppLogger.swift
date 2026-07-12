//
//  AppLogger.swift
//  AIC
//
//  Created by ahmed on 13/07/2026.
//

import Foundation
import os

/// Centralized, categorized loggers for tracing app behaviour in the Xcode
/// console or Console.app. Each category is filterable independently there
/// by subsystem + category (e.g. subsystem "<bundle id>", category "Cache").
///
/// os.Logger over print(): messages carry a severity, are visible on-device
/// (not just attached to a debugger), and stay searchable/filterable instead
/// of being scrollback noise that has to be stripped out later.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.aic.app"

    /// Cache-policy decisions: hit / stale / miss, download start/success/failure.
    static let cache = Logger(subsystem: subsystem, category: "Cache")

    /// HTTP requests and responses.
    static let network = Logger(subsystem: subsystem, category: "Network")

    /// Connectivity transitions and offline request parking.
    static let connectivity = Logger(subsystem: subsystem, category: "Connectivity")

    /// SwiftData container lifecycle: on-disk open, corruption recovery.
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// User-driven view model actions: load, refresh, retry, scroll-triggered paging.
    static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")
}
