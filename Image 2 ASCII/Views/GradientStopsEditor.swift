//
//  GradientStopsEditor.swift
//  Image 2 ASCII
//
//  Reusable editor for a positional gradient (direction + presets + color stops),
//  shared by the foreground and background color controls.
//

import SwiftUI

struct GradientStopsEditor: View {
    @Binding var stops: [GradientStop]
    @Binding var axis: GradientAxis

    var body: some View {
        Picker("Direction", selection: $axis) {
            ForEach(GradientAxis.allCases) { Text($0.label).tag($0) }
        }

        HStack {
            Text("Preset").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu("Apply") {
                ForEach(GradientPreset.allCases) { preset in
                    Button(preset.label) { stops = preset.stops }
                }
            }
            .fixedSize()
        }

        ForEach($stops) { $stop in
            HStack(spacing: 8) {
                ColorPicker("", selection: $stop.color.asColor, supportsOpacity: false)
                    .labelsHidden()
                Slider(value: $stop.location, in: 0...1)
                Text("\(Int(stop.location * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
                Button {
                    stops.removeAll { $0.id == stop.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(stops.count <= 2)
            }
        }

        Button {
            stops.append(GradientStop(location: 0.5, color: .white))
        } label: {
            Label("Add stop", systemImage: "plus.circle")
        }
        .buttonStyle(.borderless)
    }
}
