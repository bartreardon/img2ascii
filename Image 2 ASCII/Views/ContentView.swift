//
//  ContentView.swift
//  Image 2 ASCII
//

import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            ControlsPanel(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            detail
        }
        .toolbar { toolbarContent }
        .focusedSceneValue(\.appModel, model)
        .sheet(isPresented: $model.showPNGSheet) {
            PNGExportSheet(grid: model.grid) { data in
                ExportService.savePNG(data, suggestedName: "banner.png")
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            if model.settings.generatorMode == .editor {
                EditorToolbar(document: model.editor)
                Divider()
                EditorCanvasView(document: model.editor)
                    .dropDestination(for: URL.self) { urls, _ in
                        model.openEditorText(from: urls.first)
                    }
            } else if model.settings.generatorMode == .text {
                DualPreviewView(text: model.preview, isEmpty: model.grid.rows == 0)
            } else if model.hasImage {
                sourceBar
                Divider()
                DualPreviewView(text: model.preview, isEmpty: model.grid.rows == 0)
            } else {
                ImageDropView(onOpen: { model.openImage() },
                              onDrop: { url in model.loadImage(from: url) })
                    .padding(40)
            }
        }
    }

    private var sourceBar: some View {
        HStack(spacing: 12) {
            if let image = model.sourceImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 40)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(model.sourcePixelSize.width)) × \(Int(model.sourcePixelSize.height)) px")
                    .font(.caption)
                Text("\(model.grid.cols) × \(model.grid.rows) characters")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.isConverting {
                ProgressView().controlSize(.small)
            }
            Spacer()
            Button("Replace…") { model.openImage() }
            Button("Clear") { model.clearImage() }
        }
        .padding(8)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { model.openImage() } label: {
                Label("Open Image", systemImage: "photo.badge.plus")
            }
            .help("Open an image to convert (⌘O)")
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Copy as ANSI (colored)") { model.copyText(colored: true) }
                Button("Copy as plain text") { model.copyText(colored: false) }
                Button("Copy as image") { model.copyImage() }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .menuIndicator(.hidden)
            .disabled(!model.hasOutput)
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Export ANSI (colored)…") { model.exportText(colored: true) }
                Button("Export plain text…") { model.exportText(colored: false) }
                Divider()
                Button("Export PNG…") { model.showPNGSheet = true }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(!model.hasOutput)
        }
    }
}

#Preview {
    ContentView()
}
