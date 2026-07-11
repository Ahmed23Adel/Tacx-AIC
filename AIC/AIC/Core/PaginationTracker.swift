//
//  PaginationTracker.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation


struct PaginationTracker {
    /// Start loading when the user is this many rows from the end.
    private let prefetchDistance: Int

    init(prefetchDistance: Int = 5) {
        self.prefetchDistance = prefetchDistance
    }

    /// True when the row at `visibleIndex` appearing means the next page
    /// should be requested now.
    func shouldLoadNextPage(
        visibleIndex: Int,
        itemCount: Int,
        currentPage: Int,
        totalPages: Int?,
        isBusy: Bool
    ) -> Bool {
        guard !isBusy, itemCount > 0 else { return false }
        guard visibleIndex >= itemCount - prefetchDistance else { return false }
        return hasMorePages(currentPage: currentPage, totalPages: totalPages)
    }

    /// nil totalPages means the count is unknown yet — assume more exist
    /// rather than cutting pagination short.
    func hasMorePages(currentPage: Int, totalPages: Int?) -> Bool {
        guard let totalPages else { return true }
        return currentPage < totalPages
    }
}
