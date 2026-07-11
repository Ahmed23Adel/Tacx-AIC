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
        static let baseURL = "https://api.artic.edu/api/v1"
        static let iiifImageBaseURL = "https://www.artic.edu/iiif/2"
    }

    enum Cache {
        static let timeToLive: TimeInterval = 5 * 60
    }
}
