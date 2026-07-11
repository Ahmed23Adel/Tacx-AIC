//
//  AppCoordinator.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI


struct AppCoordinator: View {
    let dependencies: AppDependencies
    @State private var coordinator = Coordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ViewSearchArtworks(viewModel: ViewModelSearchArtworks(
                repository: dependencies.artworkRepository,
                networkMonitor: dependencies.networkMonitor
            ))
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .environment(coordinator)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .artworkDetail(let id):
            ViewArtworkDetail(artworkId: id)
        }
    }
}

#Preview {
    AppCoordinator(dependencies: AppDependencies())
}
