//
//  DetailInfoRow.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI


struct DetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                Text(value)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            Divider()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    VStack {
        DetailInfoRow(label: "Dimensions", value: "78 × 65.3 cm")
        DetailInfoRow(label: "Place of origin", value: "United States")
    }
    .padding()
}
