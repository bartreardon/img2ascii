//
//  FigletRenderer.swift
//  Image 2 ASCII
//
//  Lays out text into FIGlet block letters using full-width / kerning / smushing
//  per the font, implementing the standard horizontal smushing rules. Produces
//  rows of text (hardblanks already converted to spaces). Pure & nonisolated.
//

import Foundation

nonisolated enum FigletRenderer {

    /// Render one or more lines of text. Newlines stack vertically.
    static func renderLines(_ text: String, font: FigletFont) -> [String] {
        let inputLines = text.isEmpty ? [" "] : text.components(separatedBy: "\n")
        var out: [String] = []
        for (i, line) in inputLines.enumerated() {
            out.append(contentsOf: renderLine(line, font: font))
            if i < inputLines.count - 1 {
                out.append("")   // blank separator row between stacked lines
            }
        }
        return out
    }

    private static func renderLine(_ line: String, font: FigletFont) -> [String] {
        var block = [String](repeating: "", count: font.height)
        for ch in line {
            let glyph = normalize(font.rows(for: ch), height: font.height)
            block = merge(block, glyph, font: font)
        }
        // Convert hardblanks to spaces for display.
        return block.map { row in
            String(row.map { $0 == font.hardblank ? " " : $0 })
        }
    }

    /// Pad/clip a glyph to exactly `height` rows.
    private static func normalize(_ rows: [String], height: Int) -> [String] {
        var r = rows
        if r.count < height { r.append(contentsOf: Array(repeating: "", count: height - r.count)) }
        if r.count > height { r = Array(r.prefix(height)) }
        return r
    }

    // MARK: - Merge

    private static func merge(_ left: [String], _ right: [String], font: FigletFont) -> [String] {
        // Empty left block (first character): just adopt right.
        if left.allSatisfy({ $0.isEmpty }) { return right }

        let overlap = smushAmount(left, right, font: font)
        var result = [String](repeating: "", count: font.height)

        for i in 0..<font.height {
            let l = Array(left[i])
            let r = Array(right[i])
            let lLen = l.count
            let keep = max(0, lLen - overlap)

            var row = String(l.prefix(keep))
            for k in 0..<overlap {
                let li = keep + k
                let lc: Character = li < lLen ? l[li] : " "
                let rc: Character = k < r.count ? r[k] : " "
                row.append(combine(lc, rc, font: font))
            }
            if overlap < r.count {
                row += String(r[overlap...])
            }
            result[i] = row
        }
        return result
    }

    private static func smushAmount(_ left: [String], _ right: [String], font: FigletFont) -> Int {
        if font.layoutMode == .fullWidth { return 0 }

        var maxSmush = Int.max
        for i in 0..<font.height {
            let l = Array(left[i])
            let r = Array(right[i])

            var lEnd = l.count
            while lEnd > 0 && l[lEnd - 1] == " " { lEnd -= 1 }
            let lTrail = l.count - lEnd

            var rStart = 0
            while rStart < r.count && r[rStart] == " " { rStart += 1 }
            let rLead = rStart

            var amt = lTrail + rLead
            if font.layoutMode == .smushing,
               lEnd > 0, rStart < r.count,
               smush(l[lEnd - 1], r[rStart], font: font) != nil {
                amt += 1
            }
            maxSmush = min(maxSmush, amt)
        }
        return maxSmush == Int.max ? 0 : max(0, maxSmush)
    }

    private static func combine(_ a: Character, _ b: Character, font: FigletFont) -> Character {
        if a == " " { return b }
        if b == " " { return a }
        if font.layoutMode == .smushing, let s = smush(a, b, font: font) { return s }
        return b
    }

    // MARK: - Horizontal smushing rules

    private static func smush(_ a: Character, _ b: Character, font: FigletFont) -> Character? {
        let hb = font.hardblank
        let rules = font.smushRules

        // Universal smushing (smushing on, no specific rules).
        if rules == 0 {
            if a == hb && b == hb { return hb }
            if a == hb { return b }
            if b == hb { return a }
            return b   // later character wins (left-to-right)
        }

        // Rule 32: hardblanks.
        if rules & 32 != 0, a == hb, b == hb { return hb }
        if a == hb || b == hb { return nil }

        // Rule 1: equal characters.
        if rules & 1 != 0, a == b { return a }

        // Rule 2: underscore.
        if rules & 2 != 0 {
            let bars: Set<Character> = ["|", "/", "\\", "[", "]", "{", "}", "(", ")", "<", ">"]
            if a == "_" && bars.contains(b) { return b }
            if b == "_" && bars.contains(a) { return a }
        }

        // Rule 4: hierarchy.
        if rules & 4 != 0 {
            let classes = ["|", "/\\", "[]", "{}", "()", "<>"]
            func cls(_ c: Character) -> Int? { classes.firstIndex { $0.contains(c) } }
            if let ca = cls(a), let cb = cls(b), ca != cb { return cb > ca ? b : a }
        }

        // Rule 8: opposite pair.
        if rules & 8 != 0 {
            let pairs: Set<String> = ["()", ")(", "[]", "][", "{}", "}{"]
            if pairs.contains(String([a, b])) { return "|" }
        }

        // Rule 16: big X.
        if rules & 16 != 0 {
            if a == "/" && b == "\\" { return "|" }
            if a == "\\" && b == "/" { return "Y" }
            if a == ">" && b == "<" { return "X" }
        }

        return nil
    }
}
