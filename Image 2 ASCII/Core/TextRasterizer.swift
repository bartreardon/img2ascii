//
//  TextRasterizer.swift
//  Image 2 ASCII
//
//  Renders text in any installed font into an RGBA8 PixelBuffer (white glyphs on
//  a transparent ground), so it can be fed through the existing image→ASCII
//  engine. Uses CoreText so it stays nonisolated / thread-safe.
//

import Foundation
import CoreGraphics
import CoreText

nonisolated enum TextRasterizer {

    private static let maxDimension = 6000

    static func makeBuffer(text: String, fontName: String, size: Double, bold: Bool) -> PixelBuffer? {
        let raw = text.isEmpty ? " " : text
        let lines = raw.components(separatedBy: "\n").map { $0.isEmpty ? " " : $0 }

        let pointSize = max(8, min(512, size))
        let font = makeFont(name: fontName, size: pointSize, bold: bold)

        // Measure.
        let ctLines = lines.map { CTLineCreateWithAttributedString(attributed($0, font: font)) }
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        var maxWidth: CGFloat = 0
        for line in ctLines {
            var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
            maxWidth = max(maxWidth, w)
            ascent = max(ascent, a); descent = max(descent, d); leading = max(leading, l)
        }
        let lineHeight = ceil(ascent + descent + leading)
        guard lineHeight > 0, maxWidth > 0 else { return nil }

        let pad = Int(ceil(pointSize * 0.15))
        let width = min(maxDimension, Int(ceil(maxWidth)) + pad * 2)
        let height = min(maxDimension, Int(lineHeight) * lines.count + pad * 2)
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let ok: Bool = data.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: cs, bitmapInfo: bitmapInfo)
            else { return false }

            // Opaque white field so glyph coverage maps to darkness (→ density).
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // CG origin is bottom-left; draw the first line at the top.
            for (i, line) in ctLines.enumerated() {
                let baseline = CGFloat(height) - CGFloat(pad) - ascent - CGFloat(i) * lineHeight
                ctx.textPosition = CGPoint(x: CGFloat(pad), y: baseline)
                CTLineDraw(line, ctx)
            }
            return true
        }
        guard ok else { return nil }

        return PixelBuffer(width: width, height: height, pixels: data)
    }

    private static func makeFont(name: String, size: Double, bold: Bool) -> CTFont {
        let base: CTFont
        if name.isEmpty {
            base = CTFontCreateUIFontForLanguage(.system, CGFloat(size), nil)
                ?? CTFontCreateWithName("Helvetica" as CFString, CGFloat(size), nil)
        } else {
            base = CTFontCreateWithName(name as CFString, CGFloat(size), nil)
        }
        guard bold else { return base }
        return CTFontCreateCopyWithSymbolicTraits(base, CGFloat(size), nil, .boldTrait, .boldTrait) ?? base
    }

    private static func attributed(_ string: String, font: CTFont) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ]
        return NSAttributedString(string: string, attributes: attrs)
    }
}
