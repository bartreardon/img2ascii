//
//  GlyphCoverage.swift
//  Image 2 ASCII
//
//  Measures how much "ink" a character glyph puts on screen, so a custom set of
//  characters can be ordered by visual density (light → dark) instead of by the
//  order the user happened to type them. Coverage is measured in a fixed
//  monospaced font as a font-agnostic proxy. Pure & nonisolated.
//

import Foundation
import CoreGraphics
import CoreText

nonisolated enum GlyphCoverage {

    /// Return the characters ordered from least to most ink coverage (light → dark).
    static func sortedByCoverage(_ chars: [Character]) -> [Character] {
        let font = CTFontCreateWithName("Menlo" as CFString, 32, nil)
        return chars
            .map { ($0, coverage(of: $0, font: font)) }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    /// Fraction (0...1) of a fixed cell covered by the glyph's ink. Used only for
    /// relative ordering, so exact normalization is unimportant.
    static func coverage(of ch: Character, font: CTFont) -> Double {
        let dim = 40
        var data = [UInt8](repeating: 0, count: dim * dim)

        let sum: Int = data.withUnsafeMutableBytes { ptr -> Int in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base,
                                      width: dim, height: dim,
                                      bitsPerComponent: 8,
                                      bytesPerRow: dim,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return -1 }

            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(ch), attributes: attrs))
            ctx.textPosition = CGPoint(x: 6, y: 10)
            CTLineDraw(line, ctx)

            var s = 0
            for i in 0..<(dim * dim) { s += Int(ptr[i]) }
            return s
        }

        guard sum >= 0 else { return 0 }
        return Double(sum) / Double(255 * dim * dim)
    }
}
