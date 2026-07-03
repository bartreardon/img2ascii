//
//  FigletFontRegistry.swift
//  Image 2 ASCII
//
//  Locates available FIGlet (.flf) fonts: those bundled with the app plus any
//  the user has imported into Application Support. Pure & nonisolated.
//

import Foundation

nonisolated enum FigletFontRegistry {

    /// Directory where user-imported .flf fonts are stored.
    static var importedDirectory: URL? {
        guard let base = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true) else { return nil }
        return base.appendingPathComponent("Image 2 ASCII/Fonts", isDirectory: true)
    }

    private static func bundledURLs() -> [URL] {
        Bundle.main.urls(forResourcesWithExtension: "flf", subdirectory: nil) ?? []
    }

    private static func importedURLs() -> [URL] {
        guard let dir = importedDirectory,
              let items = try? FileManager.default.contentsOfDirectory(at: dir,
                                                                       includingPropertiesForKeys: nil) else { return [] }
        return items.filter { $0.pathExtension.lowercased() == "flf" }
    }

    /// All known font file URLs (bundled + imported).
    static func allURLs() -> [URL] { bundledURLs() + importedURLs() }

    /// Display names (file basename) of all available fonts, sorted.
    static func availableNames() -> [String] {
        Array(Set(allURLs().map { $0.deletingPathExtension().lastPathComponent })).sorted()
    }

    /// Resolve a font name to its file URL.
    static func url(forName name: String) -> URL? {
        allURLs().first { $0.deletingPathExtension().lastPathComponent == name }
    }
}
