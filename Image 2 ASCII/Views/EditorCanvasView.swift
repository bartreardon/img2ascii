//
//  EditorCanvasView.swift
//  Image 2 ASCII
//
//  The editable ASCII canvas: a custom NSView (in an NSScrollView) that draws
//  the editor document's cells with CoreText — the same CTLine-per-row
//  technique and Menlo metrics as PNGRenderer — and translates mouse/keyboard
//  events into EditorDocument mutations. Local edits invalidate only the dirty
//  cell rect; external changes (undo, import, zoom, scheme) arrive through
//  updateNSView observing the document.
//

import SwiftUI
import AppKit
import CoreText

// MARK: - Representable

struct EditorCanvasView: NSViewRepresentable {
    let document: EditorDocument

    func makeNSView(context: Context) -> NSScrollView {
        let canvas = EditorCanvasNSView(document: document)
        let scroll = NSScrollView()
        scroll.documentView = canvas
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = canvas.schemeBackground
        canvas.updateGeometry()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let canvas = scroll.documentView as? EditorCanvasNSView else { return }
        // Read observable properties so SwiftUI re-runs this update on change.
        _ = document.revision
        _ = document.fontSize
        _ = document.canvasScheme
        _ = document.tool
        canvas.sync()
        scroll.backgroundColor = canvas.schemeBackground
    }
}

// MARK: - NSView

@MainActor
final class EditorCanvasNSView: NSView {

    private let document: EditorDocument

    // Geometry (derived from fontSize via PNGRenderer.metrics)
    private var cellW: CGFloat = 8
    private var lineH: CGFloat = 16
    private var ascent: CGFloat = 12
    private var appliedFontSize: Double = 0
    private var font: CTFont = CTFontCreateWithName(PNGRenderer.fontName as CFString, 14, nil)

    /// Extra clickable margin beyond the grid for auto-grow.
    private let marginCols = 8
    private let marginRows = 4

    // Local-edit fast path bookkeeping
    private var lastSeenRevision = -1
    private var appliedScheme: ColorScheme = .dark

    // Interaction state
    private var lastPaintCell: GridPoint?
    private var selectionAnchor: GridPoint?
    private var cursorVisible = true
    private var blinkTimer: Timer?

    init(document: EditorDocument) {
        self.document = document
        super.init(frame: .zero)
        startBlink()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        blinkTimer?.invalidate()
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    var schemeBackground: NSColor {
        document.canvasScheme == .dark
            ? NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1)
            : NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1)
    }

    private var defaultGlyphColor: CGColor {
        document.canvasScheme == .dark
            ? CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
            : CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    }

    // MARK: Sync from SwiftUI

    /// Called from updateNSView whenever observed document state changes.
    func sync() {
        var needsFull = false
        if document.fontSize != appliedFontSize {
            updateGeometry()
            needsFull = true
        }
        if document.canvasScheme != appliedScheme {
            appliedScheme = document.canvasScheme
            needsFull = true
        }
        if document.revision != lastSeenRevision {
            lastSeenRevision = document.revision
            updateFrameSize()
            needsFull = true
        }
        if needsFull { needsDisplay = true }
    }

    func updateGeometry() {
        appliedFontSize = document.fontSize
        let m = PNGRenderer.metrics(fontSize: appliedFontSize)
        cellW = m.cellW
        lineH = m.lineH
        ascent = m.ascent
        font = CTFontCreateWithName(PNGRenderer.fontName as CFString, appliedFontSize, nil)
        updateFrameSize()
    }

    private func updateFrameSize() {
        let cols = max(document.cols, 20) + marginCols
        let rows = max(document.rows, 10) + marginRows
        let size = NSSize(width: CGFloat(cols) * cellW, height: CGFloat(rows) * lineH)
        if frame.size != size { setFrameSize(size) }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background.
        ctx.setFillColor(schemeBackground.cgColor)
        ctx.fill(dirtyRect)

        let cells = document.cells
        guard !cells.isEmpty else {
            drawGridEdge(ctx)
            return
        }

        let firstRow = max(0, Int(dirtyRect.minY / lineH))
        let lastRow = min(cells.count - 1, Int(dirtyRect.maxY / lineH))
        guard firstRow <= lastRow else {
            drawGridEdge(ctx)
            drawOverlays(ctx)
            return
        }

        // Pass 1: cell backgrounds.
        for r in firstRow...lastRow {
            let y = CGFloat(r) * lineH
            for (c, cell) in cells[r].enumerated() {
                guard let bg = cell.bg else { continue }
                ctx.setFillColor(CGColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1))
                ctx.fill(CGRect(x: CGFloat(c) * cellW, y: y, width: cellW, height: lineH))
            }
        }

        // Pass 2: glyph runs (CTLine per row; view is flipped so un-flip for text).
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        for r in firstRow...lastRow {
            let line = ctLine(forRow: cells[r])
            // In the flipped-back coordinate space, row r's baseline:
            let baseline = bounds.height - (CGFloat(r) * lineH + ascent)
            ctx.textPosition = CGPoint(x: 0, y: baseline)
            CTLineDraw(line, ctx)
        }
        ctx.restoreGState()

        drawGridEdge(ctx)
        drawOverlays(ctx)
    }

    private func ctLine(forRow row: [ASCIICell]) -> CTLine {
        let astr = NSMutableAttributedString()
        var runText = ""
        var runColor: CGColor? = nil
        var started = false

        func flush() {
            guard !runText.isEmpty else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .init(kCTFontAttributeName as String): font,
                .init(kCTForegroundColorAttributeName as String): runColor ?? defaultGlyphColor,
                .init(kCTLigatureAttributeName as String): NSNumber(value: 0),
            ]
            astr.append(NSAttributedString(string: runText, attributes: attrs))
            runText = ""
        }

        for cell in row {
            let color: CGColor? = cell.fg.map { CGColor(red: $0.r, green: $0.g, blue: $0.b, alpha: 1) }
            if !started {
                runColor = color
                started = true
            } else if !colorsEqual(color, runColor) {
                flush()
                runColor = color
            }
            runText.append(cell.glyph)
        }
        flush()
        return CTLineCreateWithAttributedString(astr)
    }

    private func colorsEqual(_ a: CGColor?, _ b: CGColor?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x == y
        default: return false
        }
    }

    /// Dashed line marking the grid's right/bottom edge (the auto-grow margin
    /// lies beyond it).
    private func drawGridEdge(_ ctx: CGContext) {
        let w = CGFloat(document.cols) * cellW
        let h = CGFloat(document.rows) * lineH
        guard w > 0, h > 0 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: 0.5, y: 0.5, width: w, height: h))
        ctx.restoreGState()
    }

    private func drawOverlays(_ ctx: CGContext) {
        // Selection overlay.
        if let sel = document.selection {
            let rect = rectForCells(sel)
            ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        }

        // Cursor (line/text tool).
        if document.tool == .line, let cur = document.cursor, cursorVisible {
            let rect = rectForCells(GridRect(cur, cur))
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(rect.insetBy(dx: 1, dy: 1))
        }
    }

    // MARK: Geometry helpers

    private func rectForCells(_ r: GridRect) -> CGRect {
        CGRect(x: CGFloat(r.minCol) * cellW,
               y: CGFloat(r.minRow) * lineH,
               width: CGFloat(r.width) * cellW,
               height: CGFloat(r.height) * lineH)
    }

    private func cellAt(_ point: NSPoint) -> GridPoint {
        GridPoint(col: max(0, Int(point.x / cellW)),
                  row: max(0, Int(point.y / lineH)))
    }

    /// Invalidate a cell region (plus one cell of slack for the cursor ring).
    private func invalidate(_ r: GridRect) {
        setNeedsDisplay(rectForCells(r).insetBy(dx: -cellW, dy: -lineH))
        lastSeenRevision = document.revision
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let cell = cellAt(convert(event.locationInWindow, from: nil))
        document.breakUndoCoalescing()

        switch document.tool {
        case .paint, .eraser:
            document.beginStroke()
            let dirty = document.stroke(from: nil, to: cell, erase: document.tool == .eraser)
            lastPaintCell = cell
            updateFrameSize()
            invalidate(dirty)
        case .line:
            document.placeCursor(cell)
            updateFrameSize()
            invalidate(GridRect(cell, cell))
        case .select:
            selectionAnchor = cell
            document.setSelection(GridRect(cell, cell))
            needsDisplay = true
            lastSeenRevision = document.revision
        }
    }

    override func mouseDragged(with event: NSEvent) {
        autoscroll(with: event)
        let cell = cellAt(convert(event.locationInWindow, from: nil))

        switch document.tool {
        case .paint, .eraser:
            guard cell != lastPaintCell else { return }
            let dirty = document.stroke(from: lastPaintCell, to: cell,
                                        erase: document.tool == .eraser)
            lastPaintCell = cell
            updateFrameSize()
            invalidate(dirty)
        case .select:
            guard let anchor = selectionAnchor else { return }
            document.setSelection(GridRect(anchor, cell))
            needsDisplay = true
            lastSeenRevision = document.revision
        case .line:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        document.endStroke()
        lastPaintCell = nil
        selectionAnchor = nil
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        // Let ⌘-shortcuts (undo etc.) travel the responder chain.
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }

        if let special = event.specialKey {
            switch special {
            case .upArrow:    handleArrow(.up); return
            case .downArrow:  handleArrow(.down); return
            case .leftArrow:  handleArrow(.left); return
            case .rightArrow: handleArrow(.right); return
            case .delete:     // Backspace
                document.backspace()
                fullInvalidate()
                return
            case .deleteForward:
                document.deleteForward()
                fullInvalidate()
                return
            case .carriageReturn, .enter:
                document.carriageReturn()
                updateFrameSize()
                fullInvalidate()
                return
            default:
                break
            }
        }

        if event.keyCode == 53 {   // Escape
            document.escape()
            fullInvalidate()
            return
        }

        // Printable characters: type at the cursor (line/text tool).
        if document.tool == .line,
           let chars = event.charactersIgnoringModifiers,
           let ch = chars.first,
           !chars.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            document.insertCharacter(ch)
            updateFrameSize()
            fullInvalidate()
            return
        }

        super.keyDown(with: event)
    }

    private func handleArrow(_ d: Direction) {
        guard document.tool == .line else { return }
        if let dirty = document.lineArrow(d) {
            updateFrameSize()
            invalidate(dirty)
        }
    }

    private func fullInvalidate() {
        needsDisplay = true
        lastSeenRevision = document.revision
    }

    // MARK: Cursor blink

    private func startBlink() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.cursorVisible.toggle()
                if self.document.tool == .line, let cur = self.document.cursor {
                    self.setNeedsDisplay(self.rectForCells(GridRect(cur, cur)).insetBy(dx: -2, dy: -2))
                }
            }
        }
    }
}
