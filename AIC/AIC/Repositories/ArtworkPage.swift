//
//  ArtworkPage.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

/// One page of search results as served to ViewModels: the artworks plus the
/// result set's total page count so pagination works identically whether the
/// page came from cache or network. totalPages is nil only if metadata was
/// never stored (fresh install serving an improbable cache hit).
struct ArtworkPage {
    let artworks: [Artwork]
    let totalPages: Int?
}
