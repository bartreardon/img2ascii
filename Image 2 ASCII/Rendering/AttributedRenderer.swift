//
//  AttributedRenderer.swift
//  Image 2 ASCII
//
//  Renders composed rows into an AttributedString for the SwiftUI preview,
//  reading the same structured cells the ANSI exporter uses (no ANSI parsing).
//  Foreground colors are applied per run; cells with no color are left unset so
//  the preview pane's color scheme drives a readable default. The banner-wide
//  background is applied by the preview view, not per-cell. Pure & nonisolated.
//

import Foundation
import SwiftUI

nonisolated enum AttributedRenderer {

    /// Build an AttributedString from a grid. Consecutive cells sharing a
    /// foreground color are coalesced into a single run for efficiency.
    static func render(_ grid: ASCIIGrid) -> AttributedString {
        let lines = GridComposer.compose(grid, colorDepth: .truecolor)
        var result = AttributedString()

        for (lineIndex, line) in lines.enumerated() {
            var runText = ""
            var runFg: RGBColor? = nil
            var runBg: RGBColor? = nil
            var started = false

            func flush() {
                guard !runText.isEmpty else { return }
                var piece = AttributedString(runText)
                if let c = runFg { piece.foregroundColor = c.color }
                if let c = runBg { piece.backgroundColor = c.color }
                result += piece
                runText = ""
            }

            for cell in line {
                if !started {
                    runFg = cell.fg
                    runBg = cell.bg
                    started = true
                } else if cell.fg != runFg || cell.bg != runBg {
                    flush()
                    runFg = cell.fg
                    runBg = cell.bg
                }
                runText.append(cell.glyph)
            }
            flush()

            if lineIndex < lines.count - 1 {
                result += AttributedString("\n")
            }
        }
        return result
    }
}

extension RGBColor {
    /// SwiftUI bridge.
    nonisolated var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
}
