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

    // MARK: Palette state

    var paintGlyph: Character = "█"
    /// nil = terminal default color.
    var fgColor: RGBColor? = .white
    /// nil = no background.
    var bgColor: RGBColor? = nil
    var lineStyle: BorderStyle = .square
    var recentGlyphs: [Character] = []
    var selFgFill = SelectionFillSpec()
    var selBgFill = SelectionFillSpec(mode: .solid, color: .black)

    // MARK: View preferences

    var canvasScheme: ColorScheme = .dark
    var fontSize: Double = 14
    private(set) var hasEverCaptured = false

    // MARK: Undo

    private struct Snapshot {
        var cells: [[ASCIICell]]
        var cursor: GridPoint?
    }
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var strokeActive = false
    private static let undoLimit = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Output

    var asGrid: ASCIIGrid {
        ASCIIGrid(cells: cells, background: .none, border: nil)
    }

    var isEmpty: Bool { cells.isEmpty }

    // MARK: - Document lifecycle

    /// Adopt composed rows (from capture or import), padded to a rectangle.
    func load(_ newCells: [[ASCIICell]]) {
        pushUndo()
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
        pushUndo()
        cells = GridEditing.resize(cells, cols: cols, rows: rows)
        bump()
    }

    // MARK: - Painting

    /// The cell the paint tool stamps.
    private var paintCell: ASCIICell {
        ASCIICell(glyph: paintGlyph, fg: fgColor, bg: bgColor)
    }

    func beginStroke() {
        guard !strokeActive else { return }
        pushUndo()
        strokeActive = true
    }

    func endStroke() { strokeActive = false }

    /// Paint or erase along a segment; returns the dirty region.
    @discardableResult
    func stroke(from a: GridPoint?, to b: GridPoint, erase: Bool) -> GridRect {
        let target: ASCIICell = erase ? .blank : paintCell
        if !erase { GridEditing.growToInclude(b, in: &cells) }
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
        GridEditing.growToInclude(p, in: &cells)
        cursor = p
        textLineStartCol = p.col
        lineDirection = nil
        bump()
    }

    /// Arrow-key line drawing. Returns the dirty region.
    @discardableResult
    func lineArrow(_ d: Direction) -> GridRect? {
        guard let cur = cursor else { return nil }
        var next = GridPoint(col: cur.col + d.delta.dc, row: cur.row + d.delta.dr)
        // Clamp at left/top; grow at right/bottom.
        if next.col < 0 || next.row < 0 { return nil }
        pushUndo(coalesceKey: "line")
        GridEditing.growToInclude(next, in: &cells)

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

    /// Move the cursor without drawing (plain arrows in select-free navigation).
    func moveCursor(_ d: Direction) {
        guard let cur = cursor else { return }
        let next = GridPoint(col: max(0, cur.col + d.delta.dc), row: max(0, cur.row + d.delta.dr))
        GridEditing.growToInclude(next, in: &cells)
        cursor = next
        lineDirection = nil
        bump()
    }

    /// Type a character at the cursor and advance. Returns the dirty region.
    @discardableResult
    func insertCharacter(_ ch: Character) -> GridRect? {
        guard let cur = cursor else { return nil }
        pushUndo(coalesceKey: "type")
        GridEditing.growToInclude(cur, in: &cells)
        GridEditing.setCell(ASCIICell(glyph: ch, fg: fgColor, bg: bgColor), at: cur, in: &cells)
        let next = GridPoint(col: cur.col + 1, row: cur.row)
        GridEditing.growToInclude(next, in: &cells)
        cursor = next
        lineDirection = nil
        noteRecent(ch)
        bump()
        return GridRect(cur, next)
    }

    func backspace() {
        guard let cur = cursor, cur.col > 0 else { return }
        pushUndo(coalesceKey: "type")
        let prev = GridPoint(col: cur.col - 1, row: cur.row)
        GridEditing.setCell(.blank, at: prev, in: &cells)
        cursor = prev
        lineDirection = nil
        bump()
    }

    func deleteForward() {
        guard let cur = cursor else { return }
        pushUndo(coalesceKey: "type")
        GridEditing.setCell(.blank, at: cur, in: &cells)
        bump()
    }

    func carriageReturn() {
        guard let cur = cursor else { return }
        let next = GridPoint(col: textLineStartCol, row: cur.row + 1)
        GridEditing.growToInclude(next, in: &cells)
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
        pushUndo()
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
        pushUndo()
        for r in sel.minRow...sel.maxRow {
            for c in sel.minCol...sel.maxCol {
                if foreground { cells[r][c].fg = nil } else { cells[r][c].bg = nil }
            }
        }
        bump()
    }

    func deleteSelectionContents() {
        guard let sel = clampedSelection() else { return }
        pushUndo()
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

    // MARK: - Undo / redo

    private var lastCoalesceKey: String?

    /// Push an undo snapshot. Consecutive pushes sharing a `coalesceKey`
    /// (e.g. a typing burst or a line stroke) collapse into one entry.
    private func pushUndo(coalesceKey: String? = nil) {
        if strokeActive { return }   // stroke already snapshotted at beginStroke()
        if let key = coalesceKey, key == lastCoalesceKey { return }
        lastCoalesceKey = coalesceKey
        undoStack.append(Snapshot(cells: cells, cursor: cursor))
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// Break undo coalescing (call on mouse-down, tool switch, cursor place).
    func breakUndoCoalescing() { lastCoalesceKey = nil }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        redoStack.append(Snapshot(cells: cells, cursor: cursor))
        cells = snap.cells
        cursor = snap.cursor
        lineDirection = nil
        lastCoalesceKey = nil
        bump()
    }

    func redo() {
        guard let snap = redoStack.popLast() else { return }
        undoStack.append(Snapshot(cells: cells, cursor: cursor))
        cells = snap.cells
        cursor = snap.cursor
        lineDirection = nil
        lastCoalesceKey = nil
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
