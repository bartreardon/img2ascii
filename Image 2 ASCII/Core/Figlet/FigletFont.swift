//
//  FigletFont.swift
//  Image 2 ASCII
//
//  Model + parser for FIGlet (.flf) fonts. Parses the header, comment block and
//  the character definitions for printable ASCII (32–126). Pure & nonisolated.
//

import Foundation

nonisolated struct FigletFont: Sendable {

    enum LayoutMode: Sendable { case fullWidth, kerning, smushing }

    let height: Int
    let baseline: Int
    let hardblank: Character
    let layoutMode: LayoutMode
    /// Active horizontal smushing rule bitmask (bits 1,2,4,8,16,32).
    let smushRules: Int
    /// glyph rows per character (hardblanks preserved, endmarks stripped).
    let glyphs: [Character: [String]]

    /// Rows for a character, falling back to space then a blank block.
    func rows(for ch: Character) -> [String] {
        if let g = glyphs[ch] { return g }
        if let space = glyphs[" "] { return space }
        return Array(repeating: String(repeating: " ", count: 1), count: height)
    }
}

nonisolated enum FigletParseError: LocalizedError {
    case notFLF
    case truncated
    var errorDescription: String? {
        switch self {
        case .notFLF:     return "Not a valid FIGlet (.flf) font."
        case .truncated:  return "The FIGlet font file is incomplete."
        }
    }
}

nonisolated enum FigletParser {

    static func parse(data: Data) throws -> FigletFont {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw FigletParseError.notFLF
        }
        // Keep line structure; FIGlet uses \n, tolerate \r\n.
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let header = lines.first, header.hasPrefix("flf2a") else { throw FigletParseError.notFLF }

        let hchars = Array(header)
        guard hchars.count > 5 else { throw FigletParseError.notFLF }
        let hardblank = hchars[5]

        let nums = String(hchars[6...]).split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { Int($0) }
        guard nums.count >= 5 else { throw FigletParseError.notFLF }
        let height = nums[0]
        let baseline = nums[1]
        let oldLayout = nums[3]
        let commentLines = nums[4]
        let fullLayout: Int? = nums.count >= 7 ? nums[6] : nil
        guard height > 0 else { throw FigletParseError.notFLF }

        // Resolve layout mode + rules.
        let (mode, rules) = resolveLayout(oldLayout: oldLayout, fullLayout: fullLayout)

        // Character data begins after header + comment lines.
        var idx = 1 + max(0, commentLines)
        guard idx + height <= lines.count else { throw FigletParseError.truncated }

        var glyphs: [Character: [String]] = [:]
        // Required set: ASCII 32...126 in order.
        for code in 32...126 {
            guard idx + height <= lines.count else { break }
            var rows: [String] = []
            for r in 0..<height {
                rows.append(stripEndmark(lines[idx + r]))
            }
            idx += height
            if let scalar = Unicode.Scalar(code) {
                glyphs[Character(scalar)] = rows
            }
        }

        guard !glyphs.isEmpty else { throw FigletParseError.truncated }
        return FigletFont(height: height, baseline: baseline, hardblank: hardblank,
                          layoutMode: mode, smushRules: rules, glyphs: glyphs)
    }

    private static func resolveLayout(oldLayout: Int, fullLayout: Int?) -> (FigletFont.LayoutMode, Int) {
        let horizMask = 1 | 2 | 4 | 8 | 16 | 32
        if let full = fullLayout {
            if full & 128 != 0 { return (.smushing, full & horizMask) }   // controlled smushing
            if full & 64 != 0 { return (.kerning, 0) }                    // fitting / kerning
            return (.fullWidth, 0)
        }
        if oldLayout < 0 { return (.fullWidth, 0) }
        if oldLayout == 0 { return (.kerning, 0) }
        return (.smushing, oldLayout & horizMask)
    }

    /// Remove the trailing endmark run (e.g. "@" or "@@") from a glyph line.
    private static func stripEndmark(_ line: String) -> String {
        guard let mark = line.last else { return line }
        var chars = Array(line)
        while chars.last == mark { chars.removeLast() }
        return String(chars)
    }
}
