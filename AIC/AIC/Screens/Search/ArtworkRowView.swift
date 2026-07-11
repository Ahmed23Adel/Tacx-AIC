//
//  ArtworkRowView.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import SwiftUI
import Kingfisher

struct ArtworkRowView: View {
    let artwork: Artwork

    private enum Layout {
        static let imageSize: CGFloat = 64
        static let cornerRadius: CGFloat = 10
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.title ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(artwork.dateDisplay ?? "Date unknown")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true) 
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(artwork.title ?? "Untitled"), \(artwork.dateDisplay ?? "date unknown")")
        .accessibilityHint("Shows the artwork's details")
        .accessibilityIdentifier("search.row.\(artwork.id)")
    }

    private var thumbnail: some View {
        KFImage(ArtworkImageURL.thumbnail(imageId: artwork.imageId))
            .placeholder {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
            .resizable()
            .scaledToFill()
            .frame(width: Layout.imageSize, height: Layout.imageSize)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
            .accessibilityHidden(true)
    }
}

#Preview {
    List {
        ArtworkRowView(artwork: Artwork(
            id: 95998,
            title: "Old Man with a Gold Chain",
            imageId: "3eaab3a3-2b47-9fdd-121c-050f6b8d9ccb",
            dateDisplay: "1631"
        ))
        ArtworkRowView(artwork: Artwork(id: 1, title: nil, imageId: nil, dateDisplay: nil))
    }
    .listStyle(.plain)
}
