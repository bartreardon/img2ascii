//
//  EditorTypes.swift
//  Image 2 ASCII
//
//  Pure value types and logic for the ASCII editor: grid geometry, tools,
//  grid-mutation primitives, the line-tool corner state machine, and selection
//  fills. All nonisolated and free of UI so they can be tested from a CLI
//  harness. EditorDocument wraps these with undo + observation.
//

import Foundation

// MARK: - Geometry

nonisolated struct GridPoint: Sendable, Hashable {
    var col: Int
    var row: Int
}

/// A normalized rectangular cell region (inclusive bounds).
nonisolated struct GridRect: Sendable, Hashable {
    var minCol: Int
    var minRow: Int
    var maxCol: Int
    var maxRow: Int

    init(minCol: Int, minRow: Int, maxCol: Int, maxRow: Int) {
        self.minCol = Swift.min(minCol, maxCol)
        self.minRow = Swift.min(minRow, maxRow)
        self.maxCol = Swift.max(minCol, maxCol)
        self.maxRow = Swift.max(minRow, maxRow)
    }

    init(_ a: GridPoint, _ b: GridPoint) {
        self.init(minCol: a.col, minRow: a.row, maxCol: b.col, maxRow: b.row)
    }

    var width: Int { maxCol - minCol + 1 }
    var height: Int { maxRow - minRow + 1 }

    func contains(_ p: GridPoint) -> Bool {
        p.col >= minCol && p.col <= maxCol && p.row >= minRow && p.row <= maxRow
    }

    func union(_ other: GridRect) -> GridRect {
        GridRect(minCol: Swift.min(minCol, other.minCol),
                 minRow: Swift.min(minRow, other.minRow),
                 maxCol: Swift.max(maxCol, other.maxCol),
                 maxRow: Swift.max(maxRow, other.maxRow))
    }
}

nonisolated enum Direction: Sendable, Hashable {
    case up, down, left, right

    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    var delta: (dc: Int, dr: Int) {
        switch self {
        case .up: return (0, -1)
        case .down: return (0, 1)
        case .left: return (-1, 0)
        case .right: return (1, 0)
        }
    }
}

// MARK: - Tools

nonisolated enum EditorTool: String, Sendable, CaseIterable, Identifiable {
    case paint
    case eraser
    case line
    case select

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paint:  return "Paint"
        case .eraser: return "Eraser"
        case .line:   return "Line / Text"
        case .select: return "Select"
        }
    }

    var systemImage: String {
        switch self {
        case .paint:  return "paintbrush.pointed"
        case .eraser: return "eraser"
        case .line:   return "pencil.line"
        case .select: return "rectangle.dashed"
        }
    }
}

/// How a selection channel (fg or bg) is filled.
nonisolated enum SelectionFillMode: String, Sendable, CaseIterable, Identifiable {
    case solid
    case gradient

    var id: String { rawValue }
    var label: String { self == .solid ? "Solid" : "Gradient" }
}

nonisolated struct SelectionFillSpec: Sendable, Hashable {
    var mode: SelectionFillMode = .solid
    var color: RGBColor = .white
    var stops: [GradientStop] = GradientPreset.fire.stops
    var axis: GradientAxis = .vertical

    /// Color for a cell at selection-relative position.
    func color(col: Int, row: Int, width: Int, height: Int) -> RGBColor {
        switch mode {
        case .solid:
            return color
        case .gradient:
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
}

// MARK: - Glyph palettes

nonisolated enum GlyphPalette {
    static let lines: [Character] = Array("─│┌┐└┘├┤┬┴┼╭╮╰╯━┃┏┓┗┛═║╔╗╚╝")
    static let shades: [Character] = Array("░▒▓█▄▀▌▐▖▗▘▝")
    static let symbols: [Character] = Array("·•●○◆◇★☆~#@*+=/\\_|")
}

// MARK: - Grid editing primitives

nonisolated enum GridEditing {

    /// Grow `cells` (padding with blanks) so `p` is inside. Left/top never grow.
    static func growToInclude(_ p: GridPoint, in cells: inout [[ASCIICell]]) {
        let needCols = p.col + 1
        let needRows = p.row + 1
        let curCols = cells.first?.count ?? 0

        if needCols > curCols {
            for i in cells.indices {
                cells[i].append(contentsOf: Array(repeating: .blank, count: needCols - cells[i].count))
            }
        }
        let width = max(curCols, needCols)
        while cells.count < needRows {
            cells.append(Array(repeating: .blank, count: width))
        }
    }

    /// Stamp one cell (no bounds growth; caller grows first). Ignores out-of-bounds.
    static func setCell(_ cell: ASCIICell, at p: GridPoint, in cells: inout [[ASCIICell]]) {
        guard p.row >= 0, p.row < cells.count, p.col >= 0, p.col < cells[p.row].count else { return }
        cells[p.row][p.col] = cell
    }

    /// All integer cells on the line from a to b inclusive (Bresenham).
    static func bresenham(from a: GridPoint, to b: GridPoint) -> [GridPoint] {
        var points: [GridPoint] = []
        var x = a.col, y = a.row
        let dx = abs(b.col - a.col), dy = -abs(b.row - a.row)
        let sx = a.col < b.col ? 1 : -1, sy = a.row < b.row ? 1 : -1
        var err = dx + dy
        while true {
            points.append(GridPoint(col: x, row: y))
            if x == b.col && y == b.row { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x += sx }
            if e2 <= dx { err += dx; y += sy }
        }
        return points
    }

    /// Resize to exactly cols×rows, trimming or padding with blanks.
    static func resize(_ cells: [[ASCIICell]], cols: Int, rows: Int) -> [[ASCIICell]] {
        let cols = max(1, cols), rows = max(1, rows)
        var out: [[ASCIICell]] = []
        out.reserveCapacity(rows)
        for r in 0..<rows {
            var row: [ASCIICell] = r < cells.count ? cells[r] : []
            if row.count > cols {
                row = Array(row.prefix(cols))
            } else if row.count < cols {
                row.append(contentsOf: Array(repeating: .blank, count: cols - row.count))
            }
            out.append(row)
        }
        return out
    }

    /// Pad ragged rows with blanks so the grid is rectangular.
    static func rectangularized(_ cells: [[ASCIICell]]) -> [[ASCIICell]] {
        let width = cells.map(\.count).max() ?? 0
        return cells.map { row in
            row.count < width
                ? row + Array(repeating: .blank, count: width - row.count)
                : row
        }
    }
}

// MARK: - Line tool logic

nonisolated enum LineToolLogic {

    /// The straight glyph for a movement direction.
    static func straightGlyph(_ d: Direction, style: BorderStyle) -> Character {
        guard let g = style.glyphs else { return "─" }
        switch d {
        case .left, .right: return g.h
        case .up, .down:    return g.v
        }
    }

    /// Corner glyph for a turn: the line came *from* one side of the cell and
    /// leaves *to* another. Sides are expressed as directions out of the cell.
    /// Box-drawing corners connect side pairs:
    ///   right+down = tl, left+down = tr, right+up = bl, left+up = br.
    static func cornerGlyph(cameFrom: Direction, goingTo: Direction, style: BorderStyle) -> Character {
        guard let g = style.glyphs else { return "+" }
        let sides: Set<Direction> = [cameFrom, goingTo]
        if sides == [.right, .down] { return g.tl }
        if sides == [.left, .down]  { return g.tr }
        if sides == [.right, .up]   { return g.bl }
        if sides == [.left, .up]    { return g.br }
        if sides == [.left, .right] { return g.h }
        if sides == [.up, .down]    { return g.v }
        // Same side twice (shouldn't happen): fall back to straight.
        return straightGlyph(goingTo, style: style)
    }

    /// Glyph to leave in the cell being exited when an arrow key moves the
    /// cursor. `prev` is the direction of the previous movement (nil at stroke
    /// start).
    static func exitGlyph(prev: Direction?, next: Direction, style: BorderStyle) -> Character {
        guard let prev, prev != next, prev != next.opposite else {
            return straightGlyph(next, style: style)
        }
        // The line entered this cell moving `prev`, so it came from the
        // `prev.opposite` side, and leaves toward `next`.
        return cornerGlyph(cameFrom: prev.opposite, goingTo: next, style: style)
    }
}
