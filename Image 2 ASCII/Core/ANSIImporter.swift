//
//  ANSIImporter.swift
//  Image 2 ASCII
//
//  Parses plain or ANSI-colored text (the dialect ANSIRenderer emits, plus the
//  standard-16 SGR codes found in files like a hand-made motd) into editable
//  cells. Unknown escape sequences are skipped gracefully. Pure & nonisolated.
//

import Foundation

nonisolated enum ANSIImporter {

    /// Parse text into rectangular rows of cells (padded with blanks).
    static func parse(_ text: String) -> [[ASCIICell]] {
        var rows: [[ASCIICell]] = []
        var current: [ASCIICell] = []
        var fg: RGBColor? = nil
        var bg: RGBColor? = nil

        var scalars = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar? = nil

        func next() -> Unicode.Scalar? {
            if let p = pending { pending = nil; return p }
            return scalars.next()
        }

        while let s = next() {
            switch s {
            case "\u{1B}":
                // Escape sequence. Only CSI (ESC [) is meaningful to us.
                guard let bracket = next() else { break }
                guard bracket == "[" else { pending = bracket; continue }
                var params = ""
                var final: Unicode.Scalar? = nil
                while let c = next() {
                    if c.value >= 0x40 && c.value <= 0x7E { final = c; break }
                    params.unicodeScalars.append(c)
                }
                if final == "m" {
                    apply(params: params, fg: &fg, bg: &bg)
                }
                // Any other final byte (cursor movement etc.): discard silently.

            case "\n":
                rows.append(current)
                current = []

            case "\r":
                continue

            case "\t":
                current.append(.blank)   // simplification: tab → one space

            default:
                guard s.value >= 0x20 || s == "\t" else { continue }   // skip other control chars
                current.append(ASCIICell(glyph: Character(s), fg: fg, bg: bg))
            }
        }
        if !current.isEmpty { rows.append(current) }

        // Drop trailing fully-empty rows, then pad to a rectangle.
        while let last = rows.last, last.isEmpty { rows.removeLast() }
        return GridEditing.rectangularized(rows)
    }

    // MARK: - SGR application

    private static func apply(params: String, fg: inout RGBColor?, bg: inout RGBColor?) {
        // Empty parameter string means reset ("\e[m").
        let parts = params.split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) ?? 0 }
        let codes = parts.isEmpty ? [0] : parts

        var i = 0
        while i < codes.count {
            let code = codes[i]
            switch code {
            case 0:
                fg = nil; bg = nil
            case 39:
                fg = nil
            case 49:
                bg = nil
            case 38, 48:
                // Extended color: 38;2;r;g;b or 38;5;N
                guard i + 1 < codes.count else { i = codes.count; break }
                let kind = codes[i + 1]
                var color: RGBColor? = nil
                if kind == 2, i + 4 < codes.count {
                    color = RGBColor(r8: codes[i + 2], g8: codes[i + 3], b8: codes[i + 4])
                    i += 4
                } else if kind == 5, i + 2 < codes.count {
                    color = ANSIColor.rgb(forIndex256: codes[i + 2])
                    i += 2
                } else {
                    i = codes.count   // malformed: stop parsing this sequence
                    break
                }
                if code == 38 { fg = color } else { bg = color }
            case 30...37:
                fg = ANSIColor.standard16[code - 30]
            case 90...97:
                fg = ANSIColor.standard16[code - 90 + 8]
            case 40...47:
                bg = ANSIColor.standard16[code - 40]
            case 100...107:
                bg = ANSIColor.standard16[code - 100 + 8]
            default:
                break   // bold/underline/etc.: ignored
            }
            i += 1
        }
    }
}
