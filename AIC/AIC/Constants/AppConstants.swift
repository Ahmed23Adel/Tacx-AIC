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
    }

    enum Cache {
        static let timeToLive: TimeInterval = 5 * 60
    }
}
