//
//  AICApp.swift
//  AIC
//
//  Created by ahmed on 09/07/2026.
//

import SwiftUI

@main
struct AICApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            AppCoordinator(dependencies: dependencies)
        }
    }
}
