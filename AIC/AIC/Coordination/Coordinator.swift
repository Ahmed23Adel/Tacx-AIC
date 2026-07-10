//
//  Coordinator.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation
import Observation


@Observable
final class Coordinator {
    var path: [AppRoute] = []

    func goToArtworkDetail(id: Int) {
        path.append(.artworkDetail(id: id))
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
