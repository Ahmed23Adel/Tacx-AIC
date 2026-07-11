//
//  OfflineBannerView.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

/// Passive connectivity notice shown above valid content: informational,
/// never blocking — the data on screen is still valid cache.
struct OfflineBannerView: View {
    var body: some View {
        Label("You're offline — showing saved artworks", systemImage: "wifi.slash")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            .accessibilityIdentifier("offlineBanner")
    }
}

#Preview {
    OfflineBannerView()
}
