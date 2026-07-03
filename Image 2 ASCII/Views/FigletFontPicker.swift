//
//  FigletFontPicker.swift
//  Image 2 ASCII
//
//  Picks a FIGlet font and imports custom .flf files.
//

import SwiftUI
import UniformTypeIdentifiers

struct FigletFontPicker: View {
    @Bindable var model: AppModel
    @State private var importing = false
    @State private var importError: String?

    private var names: [String] {
        let n = FigletFontRegistry.availableNames()
        return n.isEmpty ? [model.settings.figletFontName] : n
    }

    var body: some View {
        Picker("Font", selection: $model.settings.figletFontName) {
            ForEach(names, id: \.self) { Text($0).tag($0) }
        }

        Button {
            importing = true
        } label: {
            Label("Import .flf font…", systemImage: "plus")
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }

        if let importError {
            Text(importError).font(.caption2).foregroundStyle(.red)
        } else if FigletFontRegistry.availableNames().isEmpty {
            Text("No bundled fonts found — import a .flf file to begin.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        importError = nil
        guard case .success(let urls) = result, let dir = FigletFontRegistry.importedDirectory else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard url.pathExtension.lowercased() == "flf" else {
                    importError = "\(url.lastPathComponent) is not a .flf font."
                    continue
                }
                let dest = dir.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try? FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                model.settings.figletFontName = url.deletingPathExtension().lastPathComponent
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
