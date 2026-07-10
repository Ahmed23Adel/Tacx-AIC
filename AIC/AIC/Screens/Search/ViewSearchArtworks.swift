//
//  ViewSearchArtworks.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

struct ViewSearchArtworks: View {
    @Environment(Coordinator.self) private var coordinator
    @State private var viewModel = ViewModelSearchArtworks()

    var body: some View {
        VStack(spacing: 16) {
            Text("Search — placeholder")

            // TEMPORARY: proves the navigation wiring; replaced by real list rows.
            Button("Push detail (95998)") {
                coordinator.goToArtworkDetail(id: 95998)
            }
        }
        .navigationTitle("Artworks")
    }
}

#Preview {
    NavigationStack {
        ViewSearchArtworks()
    }
    .environment(Coordinator())
}
