//
//  ChipView.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

/// Small rounded tag for short values (the artwork's date). Long values
/// belong in DetailInfoRow, which wraps.
struct ChipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .foregroundStyle(Color.accentColor)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    ChipView(text: "1660/62")
        .padding()
}
