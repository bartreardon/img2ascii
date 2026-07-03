//
//  PNGRenderer.swift
//  Image 2 ASCII
//
//  Rasterizes the composed ASCIIGrid into a PNG with a transparent background
//  (only glyphs and any banner-background fill are drawn), at a chosen
//  resolution. Uses a fixed monospaced font so columns line up. Pure & nonisolated.
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

nonisolated enum PNGRenderer {

    static let fontName = "Menlo"
    static let maxPixels = 20000

    struct Metrics { let cellW: CGFloat; let lineH: CGFloat; let ascent: CGFloat }

    static func metrics(fontSize: CGFloat) -> Metrics {
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)

        let chars: [UniChar] = Array("M".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: 1)
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, 1)
        var advances = [CGSize](repeating: .zero, count: 1)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, 1)

        return Metrics(cellW: ceil(advances[0].width),
                       lineH: ceil(ascent + descent + leading),
                       ascent: ascent)
    }

    /// Resulting pixel dimensions for a grid at a given font size.
    static func dimensions(grid: ASCIIGrid, fontSize: CGFloat) -> CGSize {
        let lines = GridComposer.compose(grid, colorDepth: .truecolor)
        let cols = lines.map(\.count).max() ?? 0
        let m = metrics(fontSize: fontSize)
        return CGSize(width: CGFloat(cols) * m.cellW, height: CGFloat(lines.count) * m.lineH)
    }

    /// Render to PNG data. `defaultColor` is used for cells with no color.
    static func render(grid: ASCIIGrid, fontSize: CGFloat, defaultColor: RGBColor) -> Data? {
        let lines = GridComposer.compose(grid, colorDepth: .truecolor)
        guard !lines.isEmpty else { return nil }
        let cols = lines.map(\.count).max() ?? 0
        guard cols > 0 else { return nil }

        let m = metrics(fontSize: fontSize)
        let width = Int((CGFloat(cols) * m.cellW).rounded())
        let height = Int((CGFloat(lines.count) * m.lineH).rounded())
        guard width > 0, height > 0, width <= maxPixels, height <= maxPixels else { return nil }

        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bmp = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)

        var made: CGImage?
        data.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: cs, bitmapInfo: bmp)
            else { return }

            // Pass 1: per-cell background fills.
            for (r, line) in lines.enumerated() {
                let yTop = CGFloat(height) - CGFloat(r + 1) * m.lineH
                for (c, cell) in line.enumerated() {
                    guard let bg = cell.bg else { continue }
                    ctx.setFillColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1)
                    ctx.fill(CGRect(x: CGFloat(c) * m.cellW, y: yTop, width: m.cellW, height: m.lineH))
                }
            }

            // Pass 2: glyphs, one CTLine per row (monospaced → aligned columns).
            for (r, line) in lines.enumerated() {
                let baseline = CGFloat(height) - CGFloat(r) * m.lineH - m.ascent
                let astr = NSMutableAttributedString()
                for cell in line {
                    let color = cell.fg ?? defaultColor
                    let attrs: [NSAttributedString.Key: Any] = [
                        .init(kCTFontAttributeName as String): font,
                        .init(kCTForegroundColorAttributeName as String): CGColor(red: color.r, green: color.g, blue: color.b, alpha: 1),
                        .init(kCTLigatureAttributeName as String): NSNumber(value: 0),
                    ]
                    astr.append(NSAttributedString(string: String(cell.glyph), attributes: attrs))
                }
                let ctLine = CTLineCreateWithAttributedString(astr)
                ctx.textPosition = CGPoint(x: 0, y: baseline)
                CTLineDraw(ctLine, ctx)
            }

            made = ctx.makeImage()
        }

        guard let image = made else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
