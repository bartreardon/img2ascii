//
//  SettingsView.swift
//  Image 2 ASCII
//
//  App preferences (⌘,). These are the defaults applied to new windows; see
//  AppModel.init() / DefaultsKey for where they are read.
//

import SwiftUI

/// UserDefaults keys shared between SettingsView (@AppStorage) and AppModel.
enum DefaultsKey {
    static let colorDepth = "defaultColorDepth"
    static let rampName = "defaultRampName"
    static let editorFontSize = "editorFontSize"
    static let editorShowGrid = "editorShowGrid"
    static let editorShowRulers = "editorShowRulers"
    static let editorScheme = "editorScheme"
    static let previewFontName = "previewFontName"
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            EditorSettings()
                .tabItem { Label("Editor", systemImage: "square.and.pencil") }
        }
        .frame(width: 460)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @AppStorage(DefaultsKey.colorDepth) private var colorDepth = ANSIColorDepth.truecolor.rawValue
    @AppStorage(DefaultsKey.rampName) private var rampName = CharacterRamp.standard.name
    @AppStorage(DefaultsKey.previewFontName) private var previewFontName = PreviewFont.system

    var body: some View {
        Form {
            Picker("Default color depth", selection: $colorDepth) {
                ForEach(ANSIColorDepth.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Picker("Default ramp", selection: $rampName) {
                ForEach(CharacterRamp.allBuiltins) { Text($0.name).tag($0.name) }
            }
            Picker("Preview font", selection: $previewFontName) {
                Text("System Mono").tag(PreviewFont.system)
                Divider()
                ForEach(PreviewFont.names, id: \.self) { Text($0).tag($0) }
            }
            Text("Applied to new windows.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct EditorSettings: View {
    @AppStorage(DefaultsKey.editorFontSize) private var fontSize = 14.0
    @AppStorage(DefaultsKey.editorShowGrid) private var showGrid = false
    @AppStorage(DefaultsKey.editorShowRulers) private var showRulers = false
    @AppStorage(DefaultsKey.editorScheme) private var scheme = "dark"

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                LabeledContent("Default zoom", value: "\(Int(fontSize)) pt")
                Slider(value: $fontSize, in: 6...32)
            }
            Picker("Default canvas background", selection: $scheme) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
            }
            Toggle("Show character grid by default", isOn: $showGrid)
            Toggle("Show rulers by default", isOn: $showRulers)
            Text("Applied to new editor canvases.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
