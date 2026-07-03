//
//  GridTrim.swift
//  Image 2 ASCII
//
//  Trims fully-blank rows and columns from a cell grid (e.g. the empty
//  ascender/descender space around rasterized or FIGlet text) and re-adds a
//  uniform blank margin. Pure & nonisolated.
//

import Foundation

nonisolated enum GridTrim {

    static func trim(_ cells: [[ASCIICell]], margin: Int) -> [[ASCIICell]] {
        var minR = Int.max, maxR = -1, minC = Int.max, maxC = -1
        for (r, row) in cells.enumerated() {
            for (c, cell) in row.enumerated() where cell.glyph != " " {
                if r < minR { minR = r }
                if r > maxR { maxR = r }
                if c < minC { minC = c }
                if c > maxC { maxC = c }
            }
        }
        guard maxR >= 0 else { return cells }   // nothing to trim

        let m = max(0, margin)
        let width = (maxC - minC + 1) + 2 * m
        let blankRow = Array(repeating: ASCIICell.blank, count: width)

        var out: [[ASCIICell]] = []
        out.reserveCapacity((maxR - minR + 1) + 2 * m)
        for _ in 0..<m { out.append(blankRow) }
        for r in minR...maxR {
            var row = Array(repeating: ASCIICell.blank, count: m)
            for c in minC...maxC {
                row.append(c < cells[r].count ? cells[r][c] : .blank)
            }
            row.append(contentsOf: Array(repeating: .blank, count: m))
            out.append(row)
        }
        for _ in 0..<m { out.append(blankRow) }
        return out
    }
}
