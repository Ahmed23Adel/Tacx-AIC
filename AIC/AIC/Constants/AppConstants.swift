//
//  AppConstants.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

enum AppConstants {
    enum Artist {
        static let featured = "Rembrandt van Rijn"
    }

    enum API {
        static let pageLimit = 20
        // force unwrap OK: a static, known-valid literal. A malformed URL here
        // is a programmer error caught the first run in development, never a
        // runtime/field condition — nothing to recover from.
        static let baseURL = URL(string: "https://api.artic.edu/api/v1")!
        static let iiifImageBaseURL = "https://www.artic.edu/iiif/2"
    }

    enum Cache {
        static let timeToLive: TimeInterval = 5 * 60
    }
}
