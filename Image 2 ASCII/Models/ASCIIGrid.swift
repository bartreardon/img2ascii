//
//  ASCIIGrid.swift
//  Image 2 ASCII
//
//  The central artifact of the app. The conversion engine (and, later, the text/
//  FIGlet generator) produce an ASCIIGrid; the ANSI exporter and the SwiftUI
//  preview both render directly from it. Pure & Sendable.
//

import Foundation

/// A single rendered character cell.
nonisolated struct ASCIICell: Sendable, Hashable {
    var glyph: Character
    /// Foreground color, or nil for the terminal default (monochrome).
    var fg: RGBColor?
    /// Per-cell background color, or nil.
    var bg: RGBColor?

    static let blank = ASCIICell(glyph: " ", fg: nil, bg: nil)
}

/// Border description carried on a grid.
nonisolated struct BorderSpec: Sendable, Hashable {
    var style: BorderStyle
    var title: String
    var color: RGBColor?
}

/// Banner-wide background fill carried on a grid.
nonisolated enum GridBackground: Sendable, Hashable {
    case none
    case solid(RGBColor)
    case gradient(stops: [GradientStop], axis: GradientAxis)

    var isActive: Bool {
        if case .none = self { return false }
        return true
    }
}

/// A structured grid of character cells plus banner-level decoration.
nonisolated struct ASCIIGrid: Sendable {
    /// Rows of columns. Every row is expected to have `cols` entries.
    var cells: [[ASCIICell]]
    /// Banner-wide background fill applied behind every cell.
    var background: GridBackground
    /// Optional border applied around the art.
    var border: BorderSpec?
    /// Info lines placed to the right of the art (neofetch style).
    var sideText: [String]
    /// Info lines appended below the (bordered) block.
    var extraLines: [String]

    var rows: Int { cells.count }
    var cols: Int { cells.first?.count ?? 0 }

    init(cells: [[ASCIICell]],
         background: GridBackground = .none,
         border: BorderSpec? = nil,
         sideText: [String] = [],
         extraLines: [String] = []) {
        self.cells = cells
        self.background = background
        self.border = border
        self.sideText = sideText
        self.extraLines = extraLines
    }

    static let empty = ASCIIGrid(cells: [])
}
