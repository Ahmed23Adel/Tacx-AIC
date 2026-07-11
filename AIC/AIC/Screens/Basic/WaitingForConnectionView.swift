//
//  WaitingForConnectionView.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

struct WaitingForConnectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Internet Connection", systemImage: "wifi.slash")
        } description: {
            Text("Artworks will load automatically as soon as you're back online.")
        }
        .accessibilityIdentifier("waitingForConnectionView")
    }
}

#Preview {
    WaitingForConnectionView()
}
