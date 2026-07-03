//
//  FigletEngine.swift
//  Image 2 ASCII
//
//  Turns text into an ASCIIGrid of FIGlet block letters, then applies color,
//  border, background and info text the same way the image engine does.
//  Pure & nonisolated.
//

import Foundation

nonisolated enum FigletEngine {

    static func render(settings: ConversionSettings) -> ASCIIGrid {
        guard let url = FigletFontRegistry.url(forName: settings.figletFontName),
              let data = try? Data(contentsOf: url),
              let font = try? FigletParser.parse(data: data)
        else { return .empty }

        let rows = FigletRenderer.renderLines(settings.textInput, font: font)
        let width = rows.map(\.count).max() ?? 0
        guard width > 0 else { return .empty }
        let rowCount = rows.count

        var cells: [[ASCIICell]] = []
        cells.reserveCapacity(rowCount)
        for (r, line) in rows.enumerated() {
            let chars = Array(line)
            var rowCells: [ASCIICell] = []
            rowCells.reserveCapacity(width)
            for c in 0..<width {
                let ch: Character = c < chars.count ? chars[c] : " "
                if ch == " " {
                    rowCells.append(.blank)
                } else {
                    rowCells.append(ASCIICell(glyph: ch,
                                              fg: foreground(settings, col: c, row: r, cols: width, rows: rowCount),
                                              bg: nil))
                }
            }
            cells.append(rowCells)
        }

        let info = settings.infoTextLines()
        return ASCIIGrid(cells: cells,
                         background: settings.gridBackground,
                         border: settings.makeBorderSpec(),
                         sideText: info.side,
                         extraLines: info.extra)
    }

    private static func foreground(_ settings: ConversionSettings,
                                   col: Int, row: Int, cols: Int, rows: Int) -> RGBColor? {
        switch settings.colorMode {
        case .monochrome:
            return nil
        case .solid, .perPixel:   // per-pixel has no source image for text → solid
            return settings.solidColor
        case .gradient:
            let fx = cols > 1 ? Double(col) / Double(cols - 1) : 0
            let fy = rows > 1 ? Double(row) / Double(rows - 1) : 0
            let t: Double
            switch settings.gradientAxis {
            case .vertical:   t = fy
            case .horizontal: t = fx
            case .diagonal:   t = (fx + fy) / 2
            }
            return settings.gradientStops.sample(at: t)
        }
    }
}
