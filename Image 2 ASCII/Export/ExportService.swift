//
//  ExportService.swift
//  Image 2 ASCII
//
//  Clipboard helpers for the export feature. File export itself goes through
//  SwiftUI's `.fileExporter` + `TextFileDocument`; copying needs no entitlement.
//

import AppKit

@MainActor
enum ExportService {
    static func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}
