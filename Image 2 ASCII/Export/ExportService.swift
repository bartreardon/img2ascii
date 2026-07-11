//
//  ExportService.swift
//  Image 2 ASCII
//
//  Imperative open/save panels and pasteboard helpers, so the same actions can
//  be driven from the menu bar, the toolbar, or the sidebar. Panels use AppKit
//  directly; under App Sandbox the panel grants access to the chosen file.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum ExportService {

    // MARK: Clipboard

    static func copyString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    /// Put a rendered banner on the pasteboard as both PNG and TIFF so it pastes
    /// into image-aware apps (Keynote, Mail, Slack…).
    static func copyImage(pngData: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(pngData, forType: .png)
        if let tiff = NSImage(data: pngData)?.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
    }

    // MARK: Open / Save panels

    static func openFile(contentTypes: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func saveText(_ text: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Data(text.utf8).write(to: url)
    }

    static func savePNG(_ data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }
}
