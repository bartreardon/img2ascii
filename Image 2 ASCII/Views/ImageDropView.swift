//
//  ImageDropView.swift
//  Image 2 ASCII
//
//  Empty-state drop target shown before an image is loaded.
//

import SwiftUI

struct ImageDropView: View {
    var onOpen: () -> Void
    var onDrop: (URL) -> Void

    @State private var targeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop an image here")
                .font(.title3.weight(.medium))
            Text("PNG, JPEG, WebP, HEIC, GIF, TIFF, BMP")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Image…", action: onOpen)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(targeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .background(targeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            onDrop(url)
            return true
        } isTargeted: { targeted = $0 }
    }
}
