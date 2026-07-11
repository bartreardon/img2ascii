//
//  EditorCanvasView.swift
//  Image 2 ASCII
//
//  The editable ASCII canvas: a custom NSView (in an NSScrollView with optional
//  character rulers) that draws the editor document's cells with CoreText and
//  translates mouse/keyboard events into EditorDocument mutations. Glyphs are
//  positioned on an exact `col*cellW / row*lineH` grid (via CTFontDrawGlyphs)
//  so the cursor, hit-testing, backgrounds and glyphs always align.
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

        scroll.hasHorizontalRuler = true
        scroll.hasVerticalRuler = true
        let hRuler = CharacterRulerView(scrollView: scroll, orientation: .horizontalRuler)
        hRuler.clientView = canvas
        hRuler.reservedThicknessForMarkers = 10
        scroll.horizontalRulerView = hRuler
        let vRuler = CharacterRulerView(scrollView: scroll, orientation: .verticalRuler)
        vRuler.clientView = canvas
        vRuler.reservedThicknessForMarkers = 10
        scroll.verticalRulerView = vRuler

        canvas.updateGeometry()

        // Draggable resize handles: one on each ruler at the grid's far edge.
        let hImage = Self.handleImage(horizontal: true)
        let hMarker = NSRulerMarker(rulerView: hRuler,
                                    markerLocation: canvas.cellSize.width * CGFloat(document.cols),
                                    image: hImage, imageOrigin: NSPoint(x: hImage.size.width / 2, y: 0))
        hMarker.isMovable = true; hMarker.isRemovable = false
        hRuler.addMarker(hMarker)

        let vImage = Self.handleImage(horizontal: false)
        let vMarker = NSRulerMarker(rulerView: vRuler,
                                    markerLocation: canvas.cellSize.height * CGFloat(document.rows),
                                    image: vImage, imageOrigin: NSPoint(x: vImage.size.width, y: vImage.size.height / 2))
        vMarker.isMovable = true; vMarker.isRemovable = false
        vRuler.addMarker(vMarker)

        applyChrome(scroll, canvas: canvas)
        return scroll
    }

    /// Small accent-colored triangle handle for a ruler resize marker.
    private static func handleImage(horizontal: Bool) -> NSImage {
        let size = NSSize(width: 11, height: 11)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlAccentColor.setFill()
        let p = NSBezierPath()
        if horizontal {   // points down toward the column boundary
            p.move(to: NSPoint(x: 1, y: 10)); p.line(to: NSPoint(x: 10, y: 10)); p.line(to: NSPoint(x: 5.5, y: 1))
        } else {          // points right toward the row boundary
            p.move(to: NSPoint(x: 1, y: 1)); p.line(to: NSPoint(x: 1, y: 10)); p.line(to: NSPoint(x: 10, y: 5.5))
        }
        p.close(); p.fill()
        image.unlockFocus()
        return image
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let canvas = scroll.documentView as? EditorCanvasNSView else { return }
        // Touch observable properties so SwiftUI re-runs update on change.
        _ = document.revision
        _ = document.fontSize
        _ = document.canvasScheme
        _ = document.tool
        _ = document.showGrid
        _ = document.showRulers
        canvas.sync()
        applyChrome(scroll, canvas: canvas)
    }

    private func applyChrome(_ scroll: NSScrollView, canvas: EditorCanvasNSView) {
        scroll.appearance = NSAppearance(named: document.canvasScheme == .dark ? .darkAqua : .aqua)
        scroll.backgroundColor = canvas.schemeBackground
        scroll.rulersVisible = document.showRulers
        for ruler in [scroll.horizontalRulerView, scroll.verticalRulerView] {
            guard let r = ruler as? CharacterRulerView else { continue }
            r.cellW = canvas.cellSize.width
            r.lineH = canvas.cellSize.height
            let horizontal = r.orientation == .horizontalRuler
            let edge = horizontal ? canvas.cellSize.width * CGFloat(document.cols)
                                  : canvas.cellSize.height * CGFloat(document.rows)
            r.markers?.first?.markerLocation = edge
            r.needsDisplay = true
        }
    }
}

// MARK: - NSView

@MainActor
final class EditorCanvasNSView: NSView, NSUserInterfaceValidations, NSDraggingSource {

    private let document: EditorDocument

    // Geometry (from PNGRenderer.metrics — shared with PNG export).
    private var cellW: CGFloat = 8
    private var lineH: CGFloat = 16
    private var ascent: CGFloat = 12
    private var appliedFontSize: Double = 0
    private var font: CTFont = CTFontCreateWithName(PNGRenderer.fontName as CFString, 14, nil)
    private var glyphCache: [Character: CGGlyph] = [:]

    var cellSize: CGSize { CGSize(width: cellW, height: lineH) }

    /// Extra clickable margin beyond the grid for auto-grow.
    private let marginCols = 8
    private let marginRows = 4

    private var lastSeenRevision = -1
    private var appliedScheme: ColorScheme = .dark

    private var lastPaintCell: GridPoint?
    private var selectionAnchor: GridPoint?
    /// Set on mouse-down inside an existing selection; a drag then exports it.
    private var dragOutCandidate: Bool = false
    private var cursorVisible = true
    private var blinkTimer: Timer?

    init(document: EditorDocument) {
        self.document = document
        super.init(frame: .zero)
        startBlink()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { blinkTimer?.invalidate() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        document.undoManager = window?.undoManager
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .layoutArea }
    override func accessibilityLabel() -> String? { "ASCII canvas" }

    override func accessibilityValue() -> Any? {
        var parts = ["\(document.cols) by \(document.rows) characters", "\(document.tool.label) tool"]
        if let cur = document.cursor { parts.append("cursor at column \(cur.col + 1), row \(cur.row + 1)") }
        if let sel = document.selection { parts.append("selection \(sel.width) by \(sel.height)") }
        return parts.joined(separator: ", ")
    }

    var schemeBackground: NSColor {
        document.canvasScheme == .dark
            ? NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1)
            : NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1)
    }

    private var defaultGlyphCGColor: CGColor {
        document.canvasScheme == .dark
            ? CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
            : CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    }

    private var edgeColor: NSColor {
        document.canvasScheme == .dark
            ? NSColor(calibratedWhite: 0.5, alpha: 0.8)
            : NSColor(calibratedWhite: 0.4, alpha: 0.7)
    }

    private var gridColor: CGColor {
        document.canvasScheme == .dark
            ? CGColor(gray: 1, alpha: 0.08)
            : CGColor(gray: 0, alpha: 0.08)
    }

    // MARK: Sync

    func sync() {
        var needsFull = false
        if document.fontSize != appliedFontSize { updateGeometry(); needsFull = true }
        if document.canvasScheme != appliedScheme {
            appliedScheme = document.canvasScheme
            appearance = NSAppearance(named: appliedScheme == .dark ? .darkAqua : .aqua)
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
        glyphCache.removeAll(keepingCapacity: true)
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

        ctx.setFillColor(schemeBackground.cgColor)
        ctx.fill(dirtyRect)

        let cells = document.cells
        if document.showGrid { drawGrid(ctx, dirtyRect: dirtyRect) }

        if !cells.isEmpty {
            let firstRow = max(0, Int(dirtyRect.minY / lineH))
            let lastRow = min(cells.count - 1, Int(dirtyRect.maxY / lineH))
            if firstRow <= lastRow {
                // Pass 1: cell backgrounds.
                for r in firstRow...lastRow {
                    let y = CGFloat(r) * lineH
                    for (c, cell) in cells[r].enumerated() {
                        guard let bg = cell.bg else { continue }
                        ctx.setFillColor(CGColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1))
                        ctx.fill(CGRect(x: CGFloat(c) * cellW, y: y, width: cellW, height: lineH))
                    }
                }
                // Pass 2: glyphs on the exact grid.
                drawGlyphs(ctx, cells: cells, firstRow: firstRow, lastRow: lastRow)
            }
        }

        drawGridEdge(ctx)
        drawOverlays(ctx)
    }

    private func drawGlyphs(_ ctx: CGContext, cells: [[ASCIICell]], firstRow: Int, lastRow: Int) {
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)

        var glyphs: [CGGlyph] = []
        var positions: [CGPoint] = []
        var runColor = defaultGlyphCGColor

        for r in firstRow...lastRow {
            let baseline = bounds.height - (CGFloat(r) * lineH + ascent)
            glyphs.removeAll(keepingCapacity: true)
            positions.removeAll(keepingCapacity: true)
            runColor = defaultGlyphCGColor

            func flush() {
                guard !glyphs.isEmpty else { return }
                ctx.setFillColor(runColor)
                CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, ctx)
                glyphs.removeAll(keepingCapacity: true)
                positions.removeAll(keepingCapacity: true)
            }

            for (c, cell) in cells[r].enumerated() {
                guard cell.glyph != " ", let g = glyph(for: cell.glyph) else { continue }
                let color = cell.fg.map { CGColor(red: $0.r, green: $0.g, blue: $0.b, alpha: 1) }
                    ?? defaultGlyphCGColor
                if color != runColor { flush(); runColor = color }
                glyphs.append(g)
                positions.append(CGPoint(x: CGFloat(c) * cellW, y: baseline))
            }
            flush()
        }
        ctx.restoreGState()
    }

    private func glyph(for ch: Character) -> CGGlyph? {
        if let cached = glyphCache[ch] { return cached == 0 ? nil : cached }
        let utf16 = Array(String(ch).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        let ok = CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count)
        let g = ok ? glyphs[0] : 0
        glyphCache[ch] = g
        return g == 0 ? nil : g
    }

    private func drawGrid(_ ctx: CGContext, dirtyRect: NSRect) {
        let cols = document.cols, rows = document.rows
        guard cols > 0, rows > 0 else { return }
        let w = CGFloat(cols) * cellW, h = CGFloat(rows) * lineH
        ctx.saveGState()
        ctx.setStrokeColor(gridColor)
        ctx.setLineWidth(1)
        let path = CGMutablePath()
        for c in 0...cols {
            let x = CGFloat(c) * cellW
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: h))
        }
        for r in 0...rows {
            let y = CGFloat(r) * lineH
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: w, y: y))
        }
        ctx.addPath(path); ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawGridEdge(_ ctx: CGContext) {
        let w = CGFloat(document.cols) * cellW
        let h = CGFloat(document.rows) * lineH
        guard w > 0, h > 0 else { return }
        ctx.saveGState()
        ctx.setStrokeColor(edgeColor.cgColor)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: 0.5, y: 0.5, width: w, height: h))
        ctx.restoreGState()
    }

    private func drawOverlays(_ ctx: CGContext) {
        if let sel = document.selection {
            let rect = rectForCells(sel)
            ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        }
        if let cur = document.cursor, cursorVisible {
            let rect = rectForCells(GridRect(cur, cur))
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(rect.insetBy(dx: 1, dy: 1))
        }
    }

    // MARK: Geometry helpers

    private func rectForCells(_ r: GridRect) -> CGRect {
        CGRect(x: CGFloat(r.minCol) * cellW, y: CGFloat(r.minRow) * lineH,
               width: CGFloat(r.width) * cellW, height: CGFloat(r.height) * lineH)
    }

    private func cellAt(_ point: NSPoint) -> GridPoint {
        GridPoint(col: max(0, Int(point.x / cellW)), row: max(0, Int(point.y / lineH)))
    }

    private func invalidate(_ r: GridRect) {
        setNeedsDisplay(rectForCells(r).insetBy(dx: -cellW, dy: -lineH))
        lastSeenRevision = document.revision
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let cell = cellAt(convert(event.locationInWindow, from: nil))
        document.setCursor(cell)
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
            if document.selectionContains(cell) {
                // Click inside the selection begins a drag-out on movement.
                dragOutCandidate = true
            } else {
                selectionAnchor = cell
                document.setSelection(GridRect(cell, cell))
            }
            fullInvalidate()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        autoscroll(with: event)
        let cell = cellAt(convert(event.locationInWindow, from: nil))
        switch document.tool {
        case .paint, .eraser:
            guard cell != lastPaintCell else { return }
            let dirty = document.stroke(from: lastPaintCell, to: cell, erase: document.tool == .eraser)
            lastPaintCell = cell
            updateFrameSize()
            invalidate(dirty)
        case .select:
            if dragOutCandidate {
                dragOutCandidate = false
                beginSelectionDrag(with: event)
                return
            }
            guard let anchor = selectionAnchor else { return }
            document.setSelection(GridRect(anchor, cell))
            fullInvalidate()
        case .line:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        document.endStroke()
        lastPaintCell = nil
        selectionAnchor = nil
        dragOutCandidate = false
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        let shift = event.modifierFlags.contains(.shift)

        if let special = event.specialKey {
            switch special {
            case .upArrow:    arrow(.up, shift: shift); return
            case .downArrow:  arrow(.down, shift: shift); return
            case .leftArrow:  arrow(.left, shift: shift); return
            case .rightArrow: arrow(.right, shift: shift); return
            case .delete:        handleDeleteKey(forward: false); return
            case .deleteForward: handleDeleteKey(forward: true); return
            case .carriageReturn, .enter:
                if document.tool == .line { document.carriageReturn(); updateFrameSize(); fullInvalidate() }
                return
            default: break
            }
        }
        if event.keyCode == 53 { document.escape(); fullInvalidate(); return }   // Escape

        // Space: the paint tool stamps the current glyph at the cursor.
        if document.tool == .paint, event.charactersIgnoringModifiers == " " {
            document.placeGlyphAtCursor(); updateFrameSize(); fullInvalidate(); return
        }

        // Line tool: typing inserts characters.
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

    /// Arrow keys: draw (line tool) or move the cursor (Shift extends a selection).
    private func arrow(_ d: Direction, shift: Bool) {
        if document.tool == .line {
            if let dirty = document.lineArrow(d) { updateFrameSize(); invalidate(dirty) }
        } else {
            document.moveCursor(d, extend: shift && document.tool == .select)
            updateFrameSize()
            fullInvalidate()
        }
    }

    private func handleDeleteKey(forward: Bool) {
        switch document.tool {
        case .line:
            forward ? document.deleteForward() : document.backspace()
        default:
            if document.selection != nil { document.deleteSelectionContents() }
            else { document.eraseAtCursor() }
        }
        updateFrameSize()
        fullInvalidate()
    }

    // MARK: Standard Edit menu (responder-chain) actions

    @objc func copy(_ sender: Any?) {
        guard let text = document.selectionText() else { NSSound.beep(); return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc func cut(_ sender: Any?) {
        guard document.selection != nil else { NSSound.beep(); return }
        copy(sender)
        document.deleteSelectionContents()
        fullInvalidate()
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { NSSound.beep(); return }
        document.pasteCells(ANSIImporter.parse(text), at: document.pasteOrigin)
        updateFrameSize()
        fullInvalidate()
    }

    override func selectAll(_ sender: Any?) {
        document.selectAll()
        fullInvalidate()
    }

    @objc func delete(_ sender: Any?) {
        guard document.selection != nil else { NSSound.beep(); return }
        document.deleteSelectionContents()
        fullInvalidate()
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)), #selector(cut(_:)), #selector(delete(_:)):
            return document.selection != nil
        case #selector(paste(_:)):
            return NSPasteboard.general.canReadObject(forClasses: [NSString.self], options: nil)
        case #selector(selectAll(_:)):
            return document.rows > 0
        default:
            return true
        }
    }

    // MARK: Ruler marker (resize handle) callbacks

    override func rulerView(_ ruler: NSRulerView, shouldMove marker: NSRulerMarker) -> Bool {
        // Temporarily enlarge the document view so the marker (whose travel is
        // bounded by the view's length along the ruler) can be dragged far in a
        // single gesture. didMove resizes the doc and restores the normal frame.
        if ruler.orientation == .horizontalRuler {
            setFrameSize(NSSize(width: max(frame.width, 1000 * cellW), height: frame.height))
        } else {
            setFrameSize(NSSize(width: frame.width, height: max(frame.height, 1000 * lineH)))
        }
        return true
    }

    override func rulerView(_ ruler: NSRulerView, willMove marker: NSRulerMarker, toLocation location: CGFloat) -> CGFloat {
        let step = ruler.orientation == .horizontalRuler ? cellW : lineH
        return CGFloat(max(1, Int((location / step).rounded()))) * step
    }

    override func rulerView(_ ruler: NSRulerView, didMove marker: NSRulerMarker) {
        let step = ruler.orientation == .horizontalRuler ? cellW : lineH
        let n = max(1, Int((marker.markerLocation / step).rounded()))
        if ruler.orientation == .horizontalRuler {
            document.resize(cols: n, rows: document.rows)
        } else {
            document.resize(cols: document.cols, rows: n)
        }
        updateFrameSize()
        needsDisplay = true
    }

    // MARK: Selection drag-out + context menu

    private func beginSelectionDrag(with event: NSEvent) {
        guard let sel = document.clampedSelectionRect(),
              let text = document.selectionText() else { return }

        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if let grid = document.selectionGrid(),
           let png = PNGRenderer.render(grid: grid, fontSize: max(12, appliedFontSize),
                                        defaultColor: document.canvasScheme == .dark ? .white : .black) {
            item.setData(png, forType: .png)
        }

        let rect = rectForCells(sel)
        let dragItem = NSDraggingItem(pasteboardWriter: item)
        dragItem.setDraggingFrame(rect, contents: snapshot(of: rect))
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    private func snapshot(of rect: NSRect) -> NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: rect.size)
        image.addRepresentation(rep)
        return image
    }

    nonisolated func draggingSession(_ session: NSDraggingSession,
                                     sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        window?.makeFirstResponder(self)
        let menu = NSMenu()
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Delete", action: #selector(delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool { validateUserInterfaceItem(item) }

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
                if let cur = self.document.cursor {
                    self.setNeedsDisplay(self.rectForCells(GridRect(cur, cur)).insetBy(dx: -2, dy: -2))
                }
            }
        }
    }
}

// MARK: - Character ruler

/// An NSRulerView that labels character columns / rows instead of points.
@MainActor
final class CharacterRulerView: NSRulerView {
    var cellW: CGFloat = 8
    var lineH: CGFloat = 16

    override var isFlipped: Bool { true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let client = clientView else { return }
        let horizontal = orientation == .horizontalRuler
        let step = horizontal ? cellW : lineH
        guard step > 2 else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let path = NSBezierPath()
        path.lineWidth = 1
        NSColor.separatorColor.setStroke()

        let count = Int((horizontal ? client.bounds.width : client.bounds.height) / step) + 1
        for i in 0...count {
            let docPoint = horizontal ? NSPoint(x: CGFloat(i) * step, y: 0)
                                      : NSPoint(x: 0, y: CGFloat(i) * step)
            let p = convert(docPoint, from: client)
            let pos = horizontal ? p.x : p.y
            if pos < -20 || pos > (horizontal ? rect.maxX : rect.maxY) + 20 { continue }

            let major = i % 5 == 0
            let t = ruleThickness
            if horizontal {
                path.move(to: NSPoint(x: pos, y: major ? t - 6 : t - 3))
                path.line(to: NSPoint(x: pos, y: t))
                if major { (("\(i)") as NSString).draw(at: NSPoint(x: pos + 1, y: 1), withAttributes: attrs) }
            } else {
                path.move(to: NSPoint(x: major ? t - 6 : t - 3, y: pos))
                path.line(to: NSPoint(x: t, y: pos))
                if major { (("\(i)") as NSString).draw(at: NSPoint(x: 1, y: pos + 1), withAttributes: attrs) }
            }
        }
        path.stroke()
    }
}
