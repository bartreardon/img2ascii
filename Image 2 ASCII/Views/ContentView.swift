//
//  ContentView.swift
//  Image 2 ASCII
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = AppModel()
    @State private var showingImporter = false
    @State private var exporter = ExporterState()
    @State private var pngExporter = PNGExporterState()
    @State private var showingPNGSheet = false

    var body: some View {
        NavigationSplitView {
            ControlsPanel(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            detail
        }
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: ImageLoader.supportedContentTypes,
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.loadImage(from: url)
            } else if case .failure(let error) = result {
                model.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $exporter.isPresented,
                      document: TextFileDocument(text: exporter.text),
                      contentType: .plainText,
                      defaultFilename: exporter.filename) { _ in }
        .fileExporter(isPresented: $pngExporter.isPresented,
                      document: PNGFileDocument(data: pngExporter.data),
                      contentType: .png,
                      defaultFilename: "banner.png") { _ in }
        .sheet(isPresented: $showingPNGSheet) {
            PNGExportSheet(grid: model.grid) { data in pngExporter.present(data: data) }
        }
        .alert("Couldn’t load image",
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
            } else if model.settings.generatorMode == .text {
                DualPreviewView(text: model.preview, isEmpty: model.grid.rows == 0)
            } else if model.hasImage {
                sourceBar
                Divider()
                DualPreviewView(text: model.preview, isEmpty: model.grid.rows == 0)
            } else {
                ImageDropView(onOpen: { showingImporter = true },
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
            Button("Replace…") { showingImporter = true }
            Button("Clear") { model.clearImage() }
        }
        .padding(8)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingImporter = true } label: {
                Label("Open Image", systemImage: "photo.badge.plus")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Copy ANSI (colored)") {
                    ExportService.copyToPasteboard(model.outputString(colored: true))
                }
                Button("Copy plain text") {
                    ExportService.copyToPasteboard(model.outputString(colored: false))
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(model.grid.rows == 0)
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Export ANSI (colored)…") {
                    exporter.present(text: model.outputString(colored: true), filename: "banner.txt")
                }
                Button("Export plain text…") {
                    exporter.present(text: model.outputString(colored: false), filename: "banner.txt")
                }
                Divider()
                Button("Export PNG…") { showingPNGSheet = true }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(model.grid.rows == 0)
        }
    }
}

/// Small holder so a single `.fileExporter` can serve both colored & plain saves.
@Observable
final class ExporterState {
    var isPresented = false
    var text = ""
    var filename = "banner.txt"

    func present(text: String, filename: String) {
        self.text = text
        self.filename = filename
        self.isPresented = true
    }
}

/// Holds pre-rendered PNG data for the PNG `.fileExporter`.
@Observable
final class PNGExporterState {
    var isPresented = false
    var data = Data()

    func present(data: Data) {
        self.data = data
        self.isPresented = true
    }
}

#Preview {
    ContentView()
}
