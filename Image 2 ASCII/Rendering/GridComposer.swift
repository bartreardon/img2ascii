//
//  GridComposer.swift
//  Image 2 ASCII
//
//  Lays out an ASCIIGrid into a final list of rendered rows (`[[ASCIICell]]`),
//  applying the optional box border + title, neofetch-style right-side info text,
//  appended info lines, and a banner-wide background. Both the ANSI exporter and
//  the SwiftUI preview consume this same composed output. Pure & nonisolated.
//

import Foundation

nonisolated enum GridComposer {

    static let sideGutter = 3   // spaces between art block and right-side text

    /// Produce the fully laid-out rows ready for rendering.
    static func compose(_ grid: ASCIIGrid, colorDepth: ANSIColorDepth) -> [[ASCIICell]] {
        var lines: [[ASCIICell]] = []

        // 1. Build the art block (optionally bordered).
        if let border = grid.border, let g = border.style.glyphs {
            let innerWidth = grid.cols
            let bColor = border.color
            func borderCell(_ ch: Character) -> ASCIICell { ASCIICell(glyph: ch, fg: bColor, bg: nil) }

            // Top edge with embedded title.
            lines.append(topBorderRow(glyphs: g, width: innerWidth, title: border.title, color: bColor))

            // Middle rows.
            for row in grid.cells {
                var line: [ASCIICell] = [borderCell(g.v)]
                line.append(contentsOf: row)
                line.append(borderCell(g.v))
                lines.append(line)
            }

            // Bottom edge.
            var bottom: [ASCIICell] = [borderCell(g.bl)]
            bottom.append(contentsOf: repeatingCell(g.h, count: innerWidth, color: bColor))
            bottom.append(borderCell(g.br))
            lines.append(bottom)
        } else {
            lines = grid.cells
        }

        // 2. Right-side info text (aligned to the top of the art block).
        if !grid.sideText.isEmpty {
            let blockWidth = lines.map(\.count).max() ?? 0
            for (i, line) in lines.enumerated() {
                guard i < grid.sideText.count else { continue }
                var padded = line
                if padded.count < blockWidth {
                    padded.append(contentsOf: Array(repeating: .blank, count: blockWidth - padded.count))
                }
                padded.append(contentsOf: Array(repeating: .blank, count: sideGutter))
                padded.append(contentsOf: textCells(grid.sideText[i]))
                lines[i] = padded
            }
            // If there are more text lines than art rows, append the remainder.
            if grid.sideText.count > lines.count {
                let indent = blockWidth + sideGutter
                for j in lines.count..<grid.sideText.count {
                    var line = Array(repeating: ASCIICell.blank, count: indent)
                    line.append(contentsOf: textCells(grid.sideText[j]))
                    lines.append(line)
                }
            }
        }

        // 3. Appended info lines (below the block).
        for text in grid.extraLines {
            lines.append(textCells(text))
        }

        // 4. Banner-wide background: pad to a rectangle and stamp bg on every cell.
        if grid.background.isActive {
            let width = lines.map(\.count).max() ?? 0
            let height = lines.count
            for i in lines.indices {
                if lines[i].count < width {
                    lines[i].append(contentsOf: Array(repeating: .blank, count: width - lines[i].count))
                }
                for j in lines[i].indices {
                    lines[i][j].bg = backgroundColor(grid.background, col: j, row: i, width: width, height: height)
                }
            }
        }

        return lines
    }

    // MARK: - Helpers

    private static func backgroundColor(_ bg: GridBackground, col: Int, row: Int, width: Int, height: Int) -> RGBColor? {
        switch bg {
        case .none:
            return nil
        case .solid(let c):
            return c
        case .gradient(let stops, let axis):
            let fx = width > 1 ? Double(col) / Double(width - 1) : 0
            let fy = height > 1 ? Double(row) / Double(height - 1) : 0
            let t: Double
            switch axis {
            case .vertical:   t = fy
            case .horizontal: t = fx
            case .diagonal:   t = (fx + fy) / 2
            }
            return stops.sample(at: t)
        }
    }

    private static func topBorderRow(glyphs g: (tl: Character, tr: Character, bl: Character, br: Character, h: Character, v: Character),
                                     width: Int, title: String, color: RGBColor?) -> [ASCIICell] {
        var row: [ASCIICell] = [ASCIICell(glyph: g.tl, fg: color, bg: nil)]
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            row.append(contentsOf: repeatingCell(g.h, count: width, color: color))
        } else {
            // " title " surrounded by horizontal rule; truncate if needed.
            var titleChars = Array(trimmed)
            let maxTitle = max(0, width - 3)  // one leading h + two spaces
            if titleChars.count > maxTitle { titleChars = Array(titleChars.prefix(maxTitle)) }
            var used = 0
            row.append(ASCIICell(glyph: g.h, fg: color, bg: nil)); used += 1
            row.append(ASCIICell(glyph: " ", fg: color, bg: nil)); used += 1
            for ch in titleChars { row.append(ASCIICell(glyph: ch, fg: color, bg: nil)); used += 1 }
            row.append(ASCIICell(glyph: " ", fg: color, bg: nil)); used += 1
            if used < width {
                row.append(contentsOf: repeatingCell(g.h, count: width - used, color: color))
            }
        }
        row.append(ASCIICell(glyph: g.tr, fg: color, bg: nil))
        return row
    }

    private static func repeatingCell(_ ch: Character, count: Int, color: RGBColor?) -> [ASCIICell] {
        guard count > 0 else { return [] }
        return Array(repeating: ASCIICell(glyph: ch, fg: color, bg: nil), count: count)
    }

    private static func textCells(_ text: String) -> [ASCIICell] {
        text.map { ASCIICell(glyph: $0, fg: nil, bg: nil) }
    }
}
