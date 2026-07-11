//
//  EditorDocument.swift
//  Image 2 ASCII
//
//  Observable state for the ASCII editor: the editable cell grid, tool and
//  palette state, and snapshot-based undo/redo. Mutations are thin wrappers
//  around the pure GridEditing/LineToolLogic primitives; each bumps `revision`
//  so the canvas view knows to redraw.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class EditorDocument {

    // MARK: Canvas (always rectangular)

    private(set) var cells: [[ASCIICell]] = []
    var rows: Int { cells.count }
    var cols: Int { cells.first?.count ?? 0 }
    /// Bumped on every mutation; the canvas observes it to redraw.
    private(set) var revision = 0

    // MARK: Tool state

    var tool: EditorTool = .paint {
        didSet { if tool != oldValue { cursor = nil; selection = nil; lineDirection = nil } }
    }
    var cursor: GridPoint?
    var selection: GridRect?
    private var lineDirection: Direction?
    private var textLineStartCol = 0
    /// Anchor for keyboard (Shift-arrow) selection.
    private var selAnchor: GridPoint?

    // MARK: Palette state

    var paintGlyph: Character = "█"
    /// nil = terminal default color.
    var fgColor: RGBColor? = .white
    /// nil = no background.
    var bgColor: RGBColor? = nil
    /// Last chosen colors, remembered across the FG/BG on-off toggles.
    var fgColorValue: RGBColor = .white
    var bgColorValue: RGBColor = .black
    var lineStyle: BorderStyle = .square
    var recentGlyphs: [Character] = []
    var selFgFill = SelectionFillSpec()
    var selBgFill = SelectionFillSpec(mode: .solid, color: .black)

    // MARK: View preferences

    var canvasScheme: ColorScheme = .dark
    var fontSize: Double = 14
    var showGrid = false
    var showRulers = false
    /// When true, drawing past the edge does NOT grow the canvas.
    var lockedSize = false
    private(set) var hasEverCaptured = false

    // MARK: Undo (via the window's NSUndoManager)

    /// The window's undo manager, injected by the canvas view. Mutations register
    /// their inverse here so the standard Edit ▸ Undo/Redo menu drives the editor.
    weak var undoManager: UndoManager?
    private var strokeActive = false

    var canUndo: Bool { undoManager?.canUndo ?? false }
    var canRedo: Bool { undoManager?.canRedo ?? false }

    func undo() { undoManager?.undo() }
    func redo() { undoManager?.redo() }

    /// Snapshot current state and register the inverse (which re-registers redo).
    private func registerUndo(name: String) {
        guard let um = undoManager else { return }
        let oldCells = cells
        let oldCursor = cursor
        um.registerUndo(withTarget: self) { doc in
            doc.registerUndo(name: name)
            doc.cells = oldCells
            doc.cursor = oldCursor
            doc.lineDirection = nil
            doc.bump()
        }
        um.setActionName(name)
    }

    // MARK: - Output

    var asGrid: ASCIIGrid {
        ASCIIGrid(cells: cells, background: .none, border: nil)
    }

    var isEmpty: Bool { cells.isEmpty }

    // MARK: - Document lifecycle

    /// Adopt composed rows (from capture or import), padded to a rectangle.
    func load(_ newCells: [[ASCIICell]]) {
        registerUndo(name: "Replace Canvas")
        cells = GridEditing.rectangularized(newCells)
        if cells.isEmpty { cells = blankCanvas(cols: 80, rows: 24) }
        cursor = nil
        selection = nil
        lineDirection = nil
        bump()
    }

    /// Capture the current generated output (flattened, decorations baked in).
    func capture(_ composed: [[ASCIICell]]) {
        load(composed)
        hasEverCaptured = true
    }

    func newCanvas(cols: Int = 80, rows: Int = 24) {
        load(blankCanvas(cols: cols, rows: rows))
        hasEverCaptured = true
    }

    private func blankCanvas(cols: Int, rows: Int) -> [[ASCIICell]] {
        Array(repeating: Array(repeating: ASCIICell.blank, count: max(1, cols)), count: max(1, rows))
    }

    func resize(cols: Int, rows: Int) {
        guard cols != self.cols || rows != self.rows else { return }
        registerUndo(name: "Resize Canvas")
        cells = GridEditing.resize(cells, cols: cols, rows: rows)
        bump()
    }

    /// Grow the grid to include `p`, unless the canvas size is locked (in which
    /// case draws past the edge are silently clipped by `setCell`).
    private func growUnlessLocked(_ p: GridPoint, in cells: inout [[ASCIICell]]) {
        guard !lockedSize else { return }
        GridEditing.growToInclude(p, in: &cells)
    }

    // MARK: - Painting

    /// The cell the paint tool stamps.
    private var paintCell: ASCIICell {
        ASCIICell(glyph: paintGlyph, fg: fgColor, bg: bgColor)
    }

    func beginStroke() {
        guard !strokeActive else { return }
        registerUndo(name: "Draw")
        strokeActive = true
    }

    func endStroke() { strokeActive = false }

    /// Paint or erase along a segment; returns the dirty region.
    @discardableResult
    func stroke(from a: GridPoint?, to b: GridPoint, erase: Bool) -> GridRect {
        let target: ASCIICell = erase ? .blank : paintCell
        if !erase { growUnlessLocked(b, in: &cells) }
        var dirty = GridRect(b, b)
        let points = a.map { GridEditing.bresenham(from: $0, to: b) } ?? [b]
        for p in points {
            GridEditing.setCell(target, at: p, in: &cells)
            dirty = dirty.union(GridRect(p, p))
        }
        bump()
        if !erase { noteRecent(paintGlyph) }
        return dirty
    }

    // MARK: - Line / text tool

    func placeCursor(_ p: GridPoint) {
        growUnlessLocked(p, in: &cells)
        cursor = p
        textLineStartCol = p.col
        lineDirection = nil
        bump()
    }

    /// Arrow-key line drawing. Returns the dirty region.
    @discardableResult
    func lineArrow(_ d: Direction) -> GridRect? {
        guard let cur = cursor else { return nil }
        let next = GridPoint(col: cur.col + d.delta.dc, row: cur.row + d.delta.dr)
        // Clamp at left/top; grow at right/bottom.
        if next.col < 0 || next.row < 0 { return nil }
        registerUndo(name: "Draw Line")
        growUnlessLocked(next, in: &cells)

        // Fix up the cell being exited (start, straight, corner or retrace).
        let exitGlyph = LineToolLogic.exitGlyph(prev: lineDirection, next: d, style: lineStyle)
        GridEditing.setCell(ASCIICell(glyph: exitGlyph, fg: fgColor, bg: bgColor), at: cur, in: &cells)

        // Stamp the straight glyph at the new position.
        let straight = LineToolLogic.straightGlyph(d, style: lineStyle)
        GridEditing.setCell(ASCIICell(glyph: straight, fg: fgColor, bg: bgColor), at: next, in: &cells)

        cursor = next
        lineDirection = d
        bump()
        return GridRect(cur, next)
    }

    /// Ensure a cursor exists (used when arrow-navigating from an empty state).
    func ensureCursor() {
        if cursor == nil { cursor = GridPoint(col: 0, row: 0); bump() }
    }

    func setCursor(_ p: GridPoint) {
        cursor = clampToBounds(p)
        bump()
    }

    /// Move the cursor (clamped to the canvas). `extend` grows a keyboard
    /// selection from an anchor (Shift-arrow); otherwise the selection collapses.
    func moveCursor(_ d: Direction, extend: Bool) {
        ensureCursor()
        guard let cur = cursor else { return }
        let next = clampToBounds(GridPoint(col: cur.col + d.delta.dc, row: cur.row + d.delta.dr))
        if extend {
            if selAnchor == nil { selAnchor = cur }
            selection = GridRect(selAnchor!, next)
        } else {
            selAnchor = nil
            selection = nil
        }
        cursor = next
        lineDirection = nil
        bump()
    }

    /// Paint the current glyph at the cursor (paint tool, Space key).
    func placeGlyphAtCursor() {
        ensureCursor()
        guard let cur = cursor else { return }
        registerUndo(name: "Paint")
        growUnlessLocked(cur, in: &cells)
        GridEditing.setCell(ASCIICell(glyph: paintGlyph, fg: fgColor, bg: bgColor), at: cur, in: &cells)
        noteRecent(paintGlyph)
        bump()
    }

    /// Erase the cell at the cursor (eraser tool, Delete key).
    func eraseAtCursor() {
        guard let cur = cursor else { return }
        registerUndo(name: "Erase")
        GridEditing.setCell(.blank, at: cur, in: &cells)
        bump()
    }

    func selectionContains(_ p: GridPoint) -> Bool {
        guard let sel = selection else { return false }
        return p.col >= sel.minCol && p.col <= sel.maxCol && p.row >= sel.minRow && p.row <= sel.maxRow
    }

    /// The selection as a standalone grid (for drag-out / copy-as-image).
    func selectionGrid() -> ASCIIGrid? {
        guard let sel = clampedSelection() else { return nil }
        let rows = (sel.minRow...sel.maxRow).map { r in Array(cells[r][sel.minCol...sel.maxCol]) }
        return ASCIIGrid(cells: rows, background: .none, border: nil)
    }

    func clampedSelectionRect() -> GridRect? { clampedSelection() }

    private func clampToBounds(_ p: GridPoint) -> GridPoint {
        GridPoint(col: min(max(0, p.col), max(0, cols - 1)),
                  row: min(max(0, p.row), max(0, rows - 1)))
    }

    /// Type a character at the cursor and advance. Returns the dirty region.
    @discardableResult
    func insertCharacter(_ ch: Character) -> GridRect? {
        guard let cur = cursor else { return nil }
        registerUndo(name: "Typing")
        growUnlessLocked(cur, in: &cells)
        GridEditing.setCell(ASCIICell(glyph: ch, fg: fgColor, bg: bgColor), at: cur, in: &cells)
        let next = GridPoint(col: cur.col + 1, row: cur.row)
        growUnlessLocked(next, in: &cells)
        cursor = next
        lineDirection = nil
        noteRecent(ch)
        bump()
        return GridRect(cur, next)
    }

    func backspace() {
        guard let cur = cursor, cur.col > 0 else { return }
        registerUndo(name: "Typing")
        let prev = GridPoint(col: cur.col - 1, row: cur.row)
        GridEditing.setCell(.blank, at: prev, in: &cells)
        cursor = prev
        lineDirection = nil
        bump()
    }

    func deleteForward() {
        guard let cur = cursor else { return }
        registerUndo(name: "Typing")
        GridEditing.setCell(.blank, at: cur, in: &cells)
        bump()
    }

    func carriageReturn() {
        guard let cur = cursor else { return }
        let next = GridPoint(col: textLineStartCol, row: cur.row + 1)
        growUnlessLocked(next, in: &cells)
        cursor = next
        lineDirection = nil
        bump()
    }

    /// Escape: end the current line stroke / clear selection.
    func escape() {
        lineDirection = nil
        selection = nil
        bump()
    }

    // MARK: - Selection

    func setSelection(_ rect: GridRect?) {
        selection = rect
        bump()
    }

    func applySelectionFill(foreground: Bool) {
        guard let sel = clampedSelection() else { return }
        registerUndo(name: "Fill Selection")
        let spec = foreground ? selFgFill : selBgFill
        for r in sel.minRow...sel.maxRow {
            for c in sel.minCol...sel.maxCol {
                let color = spec.color(col: c - sel.minCol, row: r - sel.minRow,
                                       width: sel.width, height: sel.height)
                if foreground { cells[r][c].fg = color } else { cells[r][c].bg = color }
            }
        }
        bump()
    }

    func clearSelectionColor(foreground: Bool) {
        guard let sel = clampedSelection() else { return }
        registerUndo(name: "Clear Color")
        for r in sel.minRow...sel.maxRow {
            for c in sel.minCol...sel.maxCol {
                if foreground { cells[r][c].fg = nil } else { cells[r][c].bg = nil }
            }
        }
        bump()
    }

    func deleteSelectionContents() {
        guard let sel = clampedSelection() else { return }
        registerUndo(name: "Delete")
        for r in sel.minRow...sel.maxRow {
            for c in sel.minCol...sel.maxCol {
                cells[r][c] = .blank
            }
        }
        bump()
    }

    private func clampedSelection() -> GridRect? {
        guard let sel = selection, rows > 0, cols > 0 else { return nil }
        let r = GridRect(minCol: max(0, sel.minCol), minRow: max(0, sel.minRow),
                         maxCol: min(cols - 1, sel.maxCol), maxRow: min(rows - 1, sel.maxRow))
        guard r.minCol <= r.maxCol, r.minRow <= r.maxRow else { return nil }
        return r
    }

    // MARK: - Clipboard support (used by the canvas responder-chain actions)

    /// Plain text of the current selection (glyphs only), or nil if no selection.
    func selectionText() -> String? {
        guard let sel = clampedSelection() else { return nil }
        return (sel.minRow...sel.maxRow).map { r in
            String((sel.minCol...sel.maxCol).map { cells[r][$0].glyph })
        }.joined(separator: "\n")
    }

    func selectAll() {
        guard rows > 0, cols > 0 else { return }
        selection = GridRect(minCol: 0, minRow: 0, maxCol: cols - 1, maxRow: rows - 1)
        bump()
    }

    /// Where a paste lands: the cursor, else the selection's top-left, else origin.
    var pasteOrigin: GridPoint {
        cursor ?? selection.map { GridPoint(col: $0.minCol, row: $0.minRow) } ?? GridPoint(col: 0, row: 0)
    }

    func pasteCells(_ newCells: [[ASCIICell]], at origin: GridPoint) {
        guard !newCells.isEmpty else { return }
        registerUndo(name: "Paste")
        for (dr, row) in newCells.enumerated() {
            for (dc, cell) in row.enumerated() {
                let p = GridPoint(col: origin.col + dc, row: origin.row + dr)
                growUnlessLocked(p, in: &cells)
                GridEditing.setCell(cell, at: p, in: &cells)
            }
        }
        bump()
    }

    // MARK: - Helpers

    private func bump() { revision &+= 1 }

    private func noteRecent(_ ch: Character) {
        guard ch != " " else { return }
        recentGlyphs.removeAll { $0 == ch }
        recentGlyphs.insert(ch, at: 0)
        if recentGlyphs.count > 10 { recentGlyphs.removeLast() }
    }
}
