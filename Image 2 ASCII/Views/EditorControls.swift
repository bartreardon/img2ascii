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
                model.openEditorFile()
            } label: {
                Label("Open text file…", systemImage: "folder")
            }
            .help("Open a plain or ANSI-colored text file to edit (⇧⌘O)")
        }
    }

    // MARK: Size

    private var sizeSection: some View {
        Section("Canvas size") {
            sizeRow("Width", binding: widthBinding)
            sizeRow("Height", binding: heightBinding)
            Toggle("Lock size", isOn: Binding(get: { document.lockedSize },
                                              set: { document.lockedSize = $0 }))
            Text(document.lockedSize
                 ? "Locked: drawing past the edge is clipped. Resize with the fields, steppers, or ruler handles."
                 : "Type a value, use the steppers, drag the ruler handles, or paint past the right/bottom edge to grow.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func sizeRow(_ label: String, binding: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer()
            TextField(label, value: binding, format: .number)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
            Stepper(label, value: binding, in: 1...1000)
                .labelsHidden()
        }
    }

    private var widthBinding: Binding<Int> {
        Binding(get: { document.cols },
                set: { document.resize(cols: max(1, $0), rows: document.rows) })
    }
    private var heightBinding: Binding<Int> {
        Binding(get: { document.rows },
                set: { document.resize(cols: document.cols, rows: max(1, $0)) })
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
