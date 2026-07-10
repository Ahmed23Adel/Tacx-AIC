//
//  ViewModelArtworkDetail.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation
import Observation

@Observable
final class ViewModelArtworkDetail {
    let artworkId: Int

    init(artworkId: Int) {
        self.artworkId = artworkId
    }

    // Wired in a later step: CachedArtworkRepositoryProtocol, detail loading,
    // loading/error state.
}
