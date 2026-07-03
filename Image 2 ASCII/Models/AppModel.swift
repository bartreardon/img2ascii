//
//  AppModel.swift
//  Image 2 ASCII
//
//  MainActor coordinator between the UI and the pure conversion core. Holds the
//  loaded image + settings, runs conversion OFF the main thread (debounced), and
//  publishes the resulting grid / preview back on the main actor.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AppModel {

    /// All user-tunable parameters. Mutating any field reschedules a conversion.
    var settings = ConversionSettings() {
        didSet { scheduleRegen() }
    }

    private(set) var sourceImage: NSImage?
    private(set) var sourcePixelSize: CGSize = .zero
    private(set) var grid: ASCIIGrid = .empty
    private(set) var preview = AttributedString()
    var errorMessage: String?
    private(set) var isConverting = false

    var hasImage: Bool { pixelBuffer != nil }

    private var pixelBuffer: PixelBuffer?
    private var regenTask: Task<Void, Never>?

    // MARK: - Loading

    func loadImage(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let cg = try ImageLoader.loadCGImage(from: url)
            adopt(cg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadImage(from data: Data) {
        do {
            let cg = try ImageLoader.loadCGImage(from: data)
            adopt(cg)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func adopt(_ cg: CGImage) {
        do {
            pixelBuffer = try ImageLoader.pixelBuffer(from: cg)
            sourceImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            sourcePixelSize = CGSize(width: cg.width, height: cg.height)
            errorMessage = nil
            scheduleRegen()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearImage() {
        pixelBuffer = nil
        sourceImage = nil
        sourcePixelSize = .zero
        grid = .empty
        preview = AttributedString()
        regenTask?.cancel()
    }

    // MARK: - Conversion (debounced, off-main)

    /// In image mode we need a loaded image; text mode always has output.
    var canGenerate: Bool {
        settings.generatorMode == .text || pixelBuffer != nil
    }

    private func scheduleRegen() {
        regenTask?.cancel()
        guard canGenerate else {
            grid = .empty
            preview = AttributedString()
            return
        }
        let settings = self.settings
        let buffer = self.pixelBuffer
        isConverting = true
        regenTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { return }
            let result = await Task.detached(priority: .userInitiated) { () -> (ASCIIGrid, AttributedString) in
                let g = GeneratorPipeline.makeGrid(settings: settings, imageBuffer: buffer)
                let a = AttributedRenderer.render(g)
                return (g, a)
            }.value
            if Task.isCancelled { return }
            self?.grid = result.0
            self?.preview = result.1
            self?.isConverting = false
        }
    }

    // MARK: - Output

    /// The exportable ANSI string (colored) or plain text.
    func outputString(colored: Bool) -> String {
        ANSIRenderer.render(grid, depth: settings.colorDepth, colored: colored)
    }
}
