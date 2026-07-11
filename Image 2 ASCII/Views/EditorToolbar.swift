//
//  EditorToolbar.swift
//  Image 2 ASCII
//
//  The editor's tool strip, shown across the top of the canvas: tool picker,
//  glyph palettes, fg/bg color wells, line style, undo/redo, canvas scheme
//  and zoom.
//

import SwiftUI

struct EditorToolbar: View {
    @Bindable var document: EditorDocument

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Picker("Tool", selection: $document.tool) {
                    ForEach(EditorTool.allCases) { tool in
                        Image(systemName: tool.systemImage)
                            .help(tool.label)
                            .tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                if document.tool == .line {
                    Picker("Line style", selection: $document.lineStyle) {
                        Text("╭─╮").tag(BorderStyle.rounded)
                        Text("┌─┐").tag(BorderStyle.square)
                        Text("┏━┓").tag(BorderStyle.heavy)
                        Text("╔═╗").tag(BorderStyle.double)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("Line style for arrow-key drawing")
                }

                colorWells

                Spacer()

                Button {
                    document.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!document.canUndo)
                .help("Undo (⌘Z)")

                Button {
                    document.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!document.canRedo)
                .help("Redo (⇧⌘Z)")

                Toggle(isOn: $document.showGrid) {
                    Image(systemName: "grid")
                }
                .toggleStyle(.button)
                .help("Show character grid")

                Toggle(isOn: $document.showRulers) {
                    Image(systemName: "ruler")
                }
                .toggleStyle(.button)
                .help("Show rulers")

                Picker("Canvas", selection: $document.canvasScheme) {
                    Text("Dark").tag(ColorScheme.dark)
                    Text("Light").tag(ColorScheme.light)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Slider(value: $document.fontSize, in: 6...32)
                    .frame(width: 100)
                    .help("Zoom")
            }

            if document.tool != .select {
                glyphPalettes
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: Colors

    @ViewBuilder
    private var colorWells: some View {
        HStack(spacing: 6) {
            Toggle(isOn: fgEnabled) { Text("FG") }
                .toggleStyle(.checkbox)
                .help("Foreground color (off = terminal default)")
            ColorPicker("", selection: fgBinding, supportsOpacity: false)
                .labelsHidden()
                .disabled(document.fgColor == nil)
            Toggle(isOn: bgEnabled) { Text("BG") }
                .toggleStyle(.checkbox)
                .help("Background color (off = none)")
            ColorPicker("", selection: bgBinding, supportsOpacity: false)
                .labelsHidden()
                .disabled(document.bgColor == nil)
        }
    }

    private var fgEnabled: Binding<Bool> {
        Binding(get: { document.fgColor != nil },
                set: { document.fgColor = $0 ? document.fgColorValue : nil })
    }
    private var bgEnabled: Binding<Bool> {
        Binding(get: { document.bgColor != nil },
                set: { document.bgColor = $0 ? document.bgColorValue : nil })
    }
    private var fgBinding: Binding<Color> {
        Binding(get: { document.fgColorValue.color },
                set: { document.fgColorValue = RGBColor($0); document.fgColor = RGBColor($0) })
    }
    private var bgBinding: Binding<Color> {
        Binding(get: { document.bgColorValue.color },
                set: { document.bgColorValue = RGBColor($0); document.bgColor = RGBColor($0) })
    }

    // MARK: Glyph palettes

    private var glyphPalettes: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                paletteGroup(GlyphPalette.shades)
                paletteDivider
                paletteGroup(GlyphPalette.lines)
                paletteDivider
                paletteGroup(GlyphPalette.symbols)
                paletteDivider

                TextField("?", text: customGlyphBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(width: 30)
                    .multilineTextAlignment(.center)
                    .help("Custom glyph")

                if !document.recentGlyphs.isEmpty {
                    paletteDivider
                    Text("Recent").font(.caption2).foregroundStyle(.tertiary)
                    paletteGroup(document.recentGlyphs)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var paletteDivider: some View {
        Divider().frame(height: 16)
    }

    private func paletteGroup(_ glyphs: [Character]) -> some View {
        HStack(spacing: 2) {
            ForEach(glyphs, id: \.self) { g in
                Button {
                    document.paintGlyph = g
                } label: {
                    Text(String(g))
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 20, height: 20)
                        .background(document.paintGlyph == g
                                    ? Color.accentColor.opacity(0.3) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var customGlyphBinding: Binding<String> {
        Binding(get: { String(document.paintGlyph) },
                set: { if let ch = $0.last { document.paintGlyph = ch } })
    }
}
