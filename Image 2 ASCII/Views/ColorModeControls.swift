//
//  ColorModeControls.swift
//  Image 2 ASCII
//
//  Per-color-mode controls for the sidebar, including the gradient stop editor.
//

import SwiftUI

struct ColorModeControls: View {
    @Bindable var model: AppModel

    var body: some View {
        switch model.settings.colorMode {
        case .monochrome:
            Text("Plain density characters — no color codes are emitted.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .perPixel:
            Text("Each character is colored from the source image.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .solid:
            ColorPicker("Color", selection: $model.settings.solidColor.asColor, supportsOpacity: false)
        case .gradient:
            GradientStopsEditor(stops: $model.settings.gradientStops,
                                axis: $model.settings.gradientAxis)
        }
    }
}
