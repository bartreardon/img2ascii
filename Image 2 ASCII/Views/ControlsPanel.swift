//
//  ControlsPanel.swift
//  Image 2 ASCII
//
//  The settings sidebar: every output option grouped into a scrolling Form.
//

import SwiftUI

struct ControlsPanel: View {
    @Bindable var model: AppModel

    /// Image-density controls apply to images and the rasterized text engine.
    private var showsImageControls: Bool {
        model.settings.generatorMode == .image || model.settings.textEngine == .rasterized
    }

    var body: some View {
        Form {
            Section {
                Picker("Generate", selection: $model.settings.generatorMode) {
                    ForEach(GeneratorMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if model.settings.generatorMode == .text {
                textSection
                fontSection
            }

            if showsImageControls {
                outputSection
                charactersSection
            }
            colorSection
            backgroundSection
            borderSection
            infoSection
        }
        .formStyle(.grouped)
    }

    // MARK: Text

    private var textSection: some View {
        Section("Text") {
            TextEditor(text: $model.settings.textInput)
                .font(.body)
                .frame(minHeight: 60)
            Picker("Engine", selection: $model.settings.textEngine) {
                ForEach(TextEngine.allCases) { Text($0.label).tag($0) }
            }
            Text(model.settings.textEngine == .figlet
                 ? "Hollow block letters from a FIGlet font."
                 : "Rendered in any installed font, then converted like an image.")
                .font(.caption2).foregroundStyle(.secondary)
            Stepper(value: $model.settings.textMargin, in: 0...8) {
                LabeledContent("Margin", value: "\(model.settings.textMargin) row\(model.settings.textMargin == 1 ? "" : "s")")
            }
        }
    }

    @ViewBuilder
    private var fontSection: some View {
        switch model.settings.textEngine {
        case .rasterized:
            Section("Font") {
                Picker("Family", selection: $model.settings.rasterFontName) {
                    Text("System").tag("")
                    Divider()
                    ForEach(InstalledFonts.families, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Bold", isOn: $model.settings.rasterBold)
                VStack(alignment: .leading) {
                    LabeledContent("Render size", value: "\(Int(model.settings.rasterFontSize)) pt")
                    Slider(value: $model.settings.rasterFontSize, in: 24...256)
                    Text("Higher = more detail; width still set by Output ▸ Width.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        case .figlet:
            Section("FIGlet font") {
                FigletFontPicker(model: model)
            }
        }
    }

    // MARK: Output geometry

    private var outputSection: some View {
        Section("Output") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Width")
                    Spacer()
                    TextField("", value: $model.settings.columns, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Text("cols").foregroundStyle(.secondary)
                }
                Slider(value: columnsSlider, in: 1...150)
                Text("Drag for 1–150, or type any width above.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Character aspect")
                    Spacer()
                    Text(String(format: "%.2f", model.settings.charAspect))
                        .foregroundStyle(.secondary)
                    Button {
                        model.settings.charAspect = ConversionSettings.defaultCharAspect
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default (\(String(format: "%.2f", ConversionSettings.defaultCharAspect)))")
                    .disabled(model.settings.charAspect == ConversionSettings.defaultCharAspect)
                }
                Slider(value: $model.settings.charAspect, in: 0.3...1.0)
                Text("Lower = shorter output (compensates for tall terminal cells).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var columnsSlider: Binding<Double> {
        Binding(get: { Double(model.settings.columns) },
                set: { model.settings.columns = max(1, Int($0.rounded())) })
    }

    // MARK: Characters

    private var charactersSection: some View {
        Section("Characters") {
            Picker("Mode", selection: $model.settings.characterSetMode) {
                ForEach(CharacterSetMode.allCases) { Text($0.label).tag($0) }
            }

            switch model.settings.characterSetMode {
            case .auto:
                Picker("Ramp", selection: $model.settings.rampName) {
                    ForEach(CharacterRamp.allBuiltins) { Text($0.name).tag($0.name) }
                }
            case .custom:
                TextField("Characters", text: $model.settings.customCharacters)
                    .font(.system(.body, design: .monospaced))
                Text(customHint).font(.caption2).foregroundStyle(.secondary)
                if model.settings.customCharacters.count >= 2 {
                    Toggle("Order by glyph coverage", isOn: $model.settings.sortCustomByCoverage)
                    Toggle("Blank for brightest", isOn: $model.settings.customImplyBlank)
                    Text("Coverage orders by fill; blank-for-brightest maps the lightest areas to spaces (no need to type one).")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if model.settings.customCharacters.count == 1 {
                    VStack(alignment: .leading) {
                        LabeledContent("Threshold",
                                       value: String(format: "%.2f", model.settings.threshold))
                        Slider(value: $model.settings.threshold, in: 0...1)
                    }
                }
            }

            TextField("Exclude characters", text: $model.settings.excludedCharacters)
                .font(.system(.body, design: .monospaced))
            if !model.settings.excludedCharacters.isEmpty {
                Text("These characters are removed from the active ramp.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Toggle("Invert brightness", isOn: $model.settings.invert)
            Toggle("Solid fill", isOn: $model.settings.solidFill)
            Toggle("Transparent areas as blank", isOn: $model.settings.transparentAsSpace)
            Toggle("Crop transparent edges", isOn: $model.settings.cropTransparent)
        }
    }

    private var customHint: String {
        switch model.settings.customCharacters.count {
        case 0:  return "Enter one or more characters."
        case 1:  return "Single character → threshold fill."
        default: return "Multiple characters → custom density ramp (light → dark)."
        }
    }

    // MARK: Color

    private var colorSection: some View {
        Section("Color") {
            Picker("Mode", selection: $model.settings.colorMode) {
                ForEach(ColorMode.allCases) { Text($0.label).tag($0) }
            }
            Picker("ANSI depth", selection: $model.settings.colorDepth) {
                ForEach(ANSIColorDepth.allCases) { Text($0.label).tag($0) }
            }
            ColorModeControls(model: model)
        }
    }

    // MARK: Background

    private var backgroundSection: some View {
        Section("Background") {
            Picker("Fill", selection: $model.settings.backgroundMode) {
                ForEach(BackgroundMode.allCases) { Text($0.label).tag($0) }
            }
            switch model.settings.backgroundMode {
            case .none:
                EmptyView()
            case .solid:
                ColorPicker("Color", selection: $model.settings.backgroundColor.asColor,
                            supportsOpacity: false)
            case .gradient:
                GradientStopsEditor(stops: $model.settings.backgroundGradientStops,
                                    axis: $model.settings.backgroundGradientAxis)
            }
        }
    }

    // MARK: Border

    private var borderSection: some View {
        Section("Border") {
            Picker("Style", selection: $model.settings.borderStyle) {
                ForEach(BorderStyle.allCases) { Text($0.label).tag($0) }
            }
            if model.settings.borderStyle != .none {
                TextField("Title", text: $model.settings.borderTitle)
                Toggle("Custom border color", isOn: borderColorToggle)
                if model.settings.borderColor != nil {
                    ColorPicker("Border color",
                                selection: borderColorBinding,
                                supportsOpacity: false)
                }
            }
        }
    }

    private var borderColorToggle: Binding<Bool> {
        Binding(get: { model.settings.borderColor != nil },
                set: { model.settings.borderColor = $0 ? .white : nil })
    }

    private var borderColorBinding: Binding<Color> {
        Binding(get: { (model.settings.borderColor ?? .white).color },
                set: { model.settings.borderColor = RGBColor($0) })
    }

    // MARK: Info text

    private var infoSection: some View {
        Section("Info text") {
            Picker("Placement", selection: $model.settings.sideTextPlacement) {
                ForEach(SideTextPlacement.allCases) { Text($0.label).tag($0) }
            }
            if model.settings.sideTextPlacement != .none {
                TextEditor(text: $model.settings.infoText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
            }
        }
    }
}
