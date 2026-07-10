//
//  CachedSearchMetadataEntity.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData

/// Singleton row holding metadata about the search result set as a whole.
/// totalPages belongs to the entire result set, not to any one page — storing
/// it per page would duplicate the same value on every row. The fixed unique
/// key guarantees at most one row exists.
@Model
final class CachedSearchMetadataEntity {
    @Attribute(.unique) var key: Int
    var totalPages: Int

    init(totalPages: Int) {
        self.key = 0
        self.totalPages = totalPages
    }
}
