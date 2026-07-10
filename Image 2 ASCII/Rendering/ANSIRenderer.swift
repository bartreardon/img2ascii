//
//  ANSIRenderer.swift
//  Image 2 ASCII
//
//  Renders composed rows into a String carrying raw ANSI escape codes (real ESC
//  0x1B bytes), suitable for a terminal banner / motd. SGR codes are emitted only
//  when the fg/bg changes (run-length), and every line ends with a reset.
//  Pure & nonisolated.
//

import Foundation

nonisolated enum ANSIRenderer {

    static let esc = "\u{1B}"
    static let reset = "\u{1B}[0m"

    /// Render a grid to an ANSI-colored string.
    /// - Parameter colored: when false, emits plain text with no escape codes.
    static func render(_ grid: ASCIIGrid, depth: ANSIColorDepth, colored: Bool = true) -> String {
        let lines = GridComposer.compose(grid, colorDepth: depth)
        var out = ""

        for line in lines {
            if colored {
                out += renderColoredLine(line, depth: depth)
            } else {
                out += String(line.map(\.glyph))
            }
            out += "\n"
        }
        return out
    }

    private static func renderColoredLine(_ line: [ASCIICell], depth: ANSIColorDepth) -> String {
        var out = ""
        var curFg: RGBColor? = nil
        var curBg: RGBColor? = nil
        var anyColor = false

        for cell in line {
            if cell.fg != curFg || cell.bg != curBg {
                // Color changed — emit an SGR covering exactly the changed
                // channels; 39/49 restores a channel's default so a stale
                // color never bleeds into following cells.
                if cell.fg == nil && cell.bg == nil {
                    out += reset
                } else {
                    var params: [String] = []
                    if cell.fg != curFg {
                        params.append(cell.fg.map { ANSIColor.foregroundParams($0, depth: depth) } ?? "39")
                    }
                    if cell.bg != curBg {
                        params.append(cell.bg.map { ANSIColor.backgroundParams($0, depth: depth) } ?? "49")
                    }
                    out += "\(esc)[\(params.joined(separator: ";"))m"
                    anyColor = true
                }
                curFg = cell.fg
                curBg = cell.bg
            }
            out.append(cell.glyph)
        }

        if anyColor || curFg != nil || curBg != nil {
            out += reset
        }
        return out
    }
}
