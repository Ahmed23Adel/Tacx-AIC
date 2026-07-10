//
//  ViewArtworkDetail.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

struct ViewArtworkDetail: View {
    @State private var viewModel: ViewModelArtworkDetail

    init(artworkId: Int) {
        _viewModel = State(initialValue: ViewModelArtworkDetail(artworkId: artworkId))
    }

    var body: some View {
        Text("Detail — placeholder for artwork \(viewModel.artworkId)")
            .navigationTitle("Artwork")
    }
}

#Preview {
    NavigationStack {
        ViewArtworkDetail(artworkId: 95998)
    }
    .environment(Coordinator())
}
