//
//  ConversionEngine.swift
//  Image 2 ASCII
//
//  The pure, nonisolated heart of the app: converts a PixelBuffer into an
//  ASCIIGrid according to ConversionSettings. Knows nothing about SwiftUI or I/O.
//  The future text/FIGlet generator becomes another producer of ASCIIGrid and
//  reuses the same renderers — so keep this free of presentation concerns.
//

import Foundation

nonisolated enum ConversionEngine {

    /// Convert an image buffer into a structured ASCII grid.
    static func convert(_ buffer: PixelBuffer, settings: ConversionSettings) -> ASCIIGrid {
        let cols = max(1, settings.columns)
        guard buffer.width > 0, buffer.height > 0 else { return .empty }

        // Source rectangle: full image, or the opaque bounding box when cropping.
        var ox = 0, oy = 0, ow = buffer.width, oh = buffer.height
        if settings.cropTransparent, let b = buffer.opaqueBounds(alphaThreshold: 0.06) {
            ox = b.minX; oy = b.minY
            ow = b.maxX - b.minX + 1
            oh = b.maxY - b.minY + 1
        }
        guard ow > 0, oh > 0 else { return .empty }

        // Cell geometry with terminal aspect compensation.
        let cellW = Double(ow) / Double(cols)
        let charAspect = settings.charAspect > 0 ? settings.charAspect : ConversionSettings.defaultCharAspect
        var rows = Int((Double(oh) / cellW * charAspect).rounded())
        rows = max(1, rows)
        let cellH = Double(oh) / Double(rows)

        var ramp = activeRamp(for: settings)
        ramp = ramp.removing(Set(settings.excludedCharacters))
        // Solid fill maps every opaque pixel onto the ramp with blanks removed,
        // so nothing drops to a space (black AND white both render).
        let fillRamp = ramp.removingSpaces()
        let customChars = Array(settings.customCharacters)
        let singleFill = settings.characterSetMode == .custom && customChars.count == 1

        var cells: [[ASCIICell]] = []
        cells.reserveCapacity(rows)

        for r in 0..<rows {
            let y0 = oy + Int((Double(r) * cellH).rounded(.down))
            let y1 = oy + Int((Double(r + 1) * cellH).rounded(.down))
            var row: [ASCIICell] = []
            row.reserveCapacity(cols)

            for c in 0..<cols {
                let x0 = ox + Int((Double(c) * cellW).rounded(.down))
                let x1 = ox + Int((Double(c + 1) * cellW).rounded(.down))
                let s = buffer.averageCell(x0: x0, y0: y0, x1: x1, y1: y1)

                // Transparent regions become blank cells.
                if settings.transparentAsSpace && s.a < 0.12 {
                    row.append(.blank)
                    continue
                }

                let brightness = settings.invert ? (1 - s.luma) : s.luma

                // Glyph selection.
                let glyph: Character
                if settings.solidFill {
                    // Fill every opaque pixel using the ramp (blanks removed) so
                    // both dark and light areas render; color carries the image.
                    glyph = fillRamp.glyph(forBrightness: brightness)
                } else if singleFill {
                    let pass = settings.invert ? (s.luma <= settings.threshold)
                                               : (s.luma >= settings.threshold)
                    glyph = pass ? customChars[0] : " "
                } else {
                    glyph = ramp.glyph(forBrightness: brightness)
                }

                // A space carries no color.
                if glyph == " " {
                    row.append(.blank)
                    continue
                }

                let fg = foreground(for: settings,
                                    cellColor: RGBColor(r: s.r, g: s.g, b: s.b),
                                    col: c, row: r, cols: cols, rows: rows)
                row.append(ASCIICell(glyph: glyph, fg: fg, bg: nil))
            }
            cells.append(row)
        }

        let info = settings.infoTextLines()
        return ASCIIGrid(cells: cells,
                         background: settings.gridBackground,
                         border: settings.makeBorderSpec(),
                         sideText: info.side,
                         extraLines: info.extra)
    }

    // MARK: - Helpers

    private static func activeRamp(for settings: ConversionSettings) -> CharacterRamp {
        switch settings.characterSetMode {
        case .auto:
            return CharacterRamp.named(settings.rampName)
        case .custom:
            let chars = Array(settings.customCharacters)
            if chars.count >= 2 {
                var ordered = settings.sortCustomByCoverage
                    ? GlyphCoverage.sortedByCoverage(chars)
                    : chars
                // Map the brightest level to a blank unless the user added a space.
                if settings.customImplyBlank, ordered.first != " " {
                    ordered.insert(" ", at: 0)
                }
                return CharacterRamp(name: "custom", characters: ordered)
            }
            // Single (or empty) char: fall back to the glyph for fill handling.
            return CharacterRamp(name: "custom", characters: chars.isEmpty ? ["#"] : chars)
        }
    }

    private static func foreground(for settings: ConversionSettings,
                                   cellColor: RGBColor,
                                   col: Int, row: Int, cols: Int, rows: Int) -> RGBColor? {
        switch settings.colorMode {
        case .monochrome:
            return nil
        case .perPixel:
            return cellColor
        case .solid:
            return settings.solidColor
        case .gradient:
            let t = gradientPosition(axis: settings.gradientAxis,
                                     col: col, row: row, cols: cols, rows: rows)
            return settings.gradientStops.sample(at: t)
        }
    }

    private static func gradientPosition(axis: GradientAxis,
                                         col: Int, row: Int, cols: Int, rows: Int) -> Double {
        let fx = cols > 1 ? Double(col) / Double(cols - 1) : 0
        let fy = rows > 1 ? Double(row) / Double(rows - 1) : 0
        switch axis {
        case .vertical:   return fy
        case .horizontal: return fx
        case .diagonal:   return (fx + fy) / 2
        }
    }
}
