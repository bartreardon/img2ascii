//
//  PNGExportSheet.swift
//  Image 2 ASCII
//
//  Options for exporting the current output as a transparent PNG.
//

import SwiftUI

struct PNGExportSheet: View {
    let grid: ASCIIGrid
    var onExport: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fontSize: Double = 16
    @State private var textColor: Color = .white

    private var dimensions: CGSize {
        PNGRenderer.dimensions(grid: grid, fontSize: fontSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export PNG").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Resolution", value: "\(Int(fontSize)) px / row")
                Slider(value: $fontSize, in: 6...48)
                Text("Output: \(Int(dimensions.width)) × \(Int(dimensions.height)) px")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ColorPicker("Uncolored text", selection: $textColor, supportsOpacity: false)

            Text("Background is transparent (any banner-background fill is kept).")
                .font(.caption2).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Export…") {
                    if let data = PNGRenderer.render(grid: grid,
                                                     fontSize: fontSize,
                                                     defaultColor: RGBColor(textColor)) {
                        onExport(data)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(dimensions.width < 1 || dimensions.height < 1)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
