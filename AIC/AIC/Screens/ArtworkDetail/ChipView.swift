//
//  ChipView.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI

struct ChipView: View {
    enum Style {
        case tinted
        case neutral
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .foregroundStyle(style == .tinted ? Color.accentColor : .primary)
            .background(background)
            .clipShape(Capsule())
    }

    private var background: Color {
        switch style {
        case .tinted: Color.accentColor.opacity(0.15)
        case .neutral: Color(.secondarySystemFill)
        }
    }
}

#Preview {
    HStack {
        ChipView(text: "1930", style: .tinted)
        ChipView(text: "Oil on beaverboard", style: .neutral)
    }
    .padding()
}
