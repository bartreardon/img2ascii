//
//  EditorControls.swift
//  Image 2 ASCII
//
//  Sidebar sections shown in editor mode: canvas lifecycle (capture / new /
//  open), size trimming, and selection color operations.
//

import SwiftUI
import UniformTypeIdentifiers

struct EditorControls: View {
    @Bindable var model: AppModel
    @State private var showingOpen = false
    @State private var openError: String?
    @State private var widthText = ""
    @State private var heightText = ""

    private var document: EditorDocument { model.editor }

    var body: some View {
        canvasSection
        sizeSection
        selectionSection
    }

    // MARK: Canvas lifecycle

    private var canvasSection: some View {
        Section("Canvas") {
            Button {
                model.captureIntoEditor()
            } label: {
                Label("Capture current output", systemImage: "square.and.arrow.down.on.square")
            }
            .help("Copy the Image/Text result into the editor (replaces the canvas)")

            Button {
                document.newCanvas()
            } label: {
                Label("New canvas", systemImage: "doc")
            }

            Button {
                showingOpen = true
            } label: {
                Label("Open text file…", systemImage: "folder")
            }
            .fileImporter(isPresented: $showingOpen,
                          allowedContentTypes: [.plainText, .data],
                          allowsMultipleSelection: false) { result in
                handleOpen(result)
            }

            if let openError {
                Text(openError).font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private func handleOpen(_ result: Result<[URL], Error>) {
        openError = nil
        guard case .success(let urls) = result, let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self)
            let cells = ANSIImporter.parse(text)
            guard !cells.isEmpty else {
                openError = "The file contains no text."
                return
            }
            document.load(cells)
        } catch {
            openError = error.localizedDescription
        }
    }

    // MARK: Size

    private var sizeSection: some View {
        Section("Canvas size") {
            LabeledContent("Current", value: "\(document.cols) × \(document.rows)")
            HStack {
                TextField("Width", text: $widthText, prompt: Text("\(document.cols)"))
                    .frame(width: 60)
                Text("×").foregroundStyle(.secondary)
                TextField("Height", text: $heightText, prompt: Text("\(document.rows)"))
                    .frame(width: 60)
                Button("Apply") { applySize() }
                    .disabled(Int(widthText) == nil && Int(heightText) == nil)
            }
            Text("Painting past the right/bottom edge grows the canvas automatically.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func applySize() {
        let cols = Int(widthText) ?? document.cols
        let rows = Int(heightText) ?? document.rows
        document.resize(cols: max(1, cols), rows: max(1, rows))
        widthText = ""
        heightText = ""
    }

    // MARK: Selection

    @ViewBuilder
    private var selectionSection: some View {
        Section("Selection") {
            if let sel = document.selection {
                LabeledContent("Area", value: "\(sel.width) × \(sel.height)")

                fillEditor(title: "Foreground", spec: Binding(
                    get: { document.selFgFill }, set: { document.selFgFill = $0 }))
                Button("Apply to foreground") { document.applySelectionFill(foreground: true) }

                fillEditor(title: "Background", spec: Binding(
                    get: { document.selBgFill }, set: { document.selBgFill = $0 }))
                Button("Apply to background") { document.applySelectionFill(foreground: false) }

                Divider()
                HStack {
                    Button("Clear FG") { document.clearSelectionColor(foreground: true) }
                    Button("Clear BG") { document.clearSelectionColor(foreground: false) }
                    Button("Delete", role: .destructive) { document.deleteSelectionContents() }
                }
            } else {
                Text("Use the Select tool to drag a rectangle, then recolor or clear it here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func fillEditor(title: String, spec: Binding<SelectionFillSpec>) -> some View {
        Picker(title, selection: spec.mode) {
            ForEach(SelectionFillMode.allCases) { Text($0.label).tag($0) }
        }
        switch spec.wrappedValue.mode {
        case .solid:
            ColorPicker("\(title) color", selection: spec.color.asColor, supportsOpacity: false)
        case .gradient:
            GradientStopsEditor(stops: spec.stops, axis: spec.axis)
        }
    }
}
