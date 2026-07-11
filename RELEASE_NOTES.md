## Image 2 ASCII 1.1.0

The headline feature is a brand-new **interactive ASCII editor**, plus a big pass to make the app feel properly at home on macOS.

### ✏️ New: ASCII Editor
Turn any generated banner — or a blank canvas — into something you can hand-tweak.
- **Paint, Eraser, Line/Text, and Select** tools
- **Draw box-drawing lines with the arrow keys** — corners are inserted automatically (rounded / square / heavy / double)
- **Cursor navigation in every tool:** arrows move, **Space** paints, **Delete** erases, **Shift-arrow** selects
- **Glyph palettes** (shades, lines, symbols, custom + recents)
- **Selection fills** — solid or gradient, foreground and background independently
- **Capture** the current image/text output, start a **new canvas**, or **open** a text/ANSI file to edit
- Editable **canvas size** with draggable ruler handles, auto-grow, and a lock option
- **Rulers, character grid, zoom**, dark/light canvas, and **undo/redo**

### 🍎 Now a proper Mac app
- **Menu bar & keyboard shortcuts** for everything (⌘N, ⌘O, ⌘E, ⇧⌘C, ⌘±, …)
- **Settings window (⌘,)** with defaults that persist across launches
- **Drag & drop** — drag a banner *out* to Finder/other apps as PNG or text, and drag text/ANSI files (or clippings) *into* the editor
- **Copy as image**, plus standard **Cut/Copy/Paste** and a right-click menu in the editor
- **Open ANSI-colored `.txt` / motd files** and edit them with colors intact
- **VoiceOver** support and accessibility labels

### 🐛 Fixes
- Editor glyphs now sit exactly on the cell grid (cursor, drawing and clicks all agree)
- Dark-mode canvas edge is visible
- Text clippings import their actual text, not the raw plist bytes
- No more stale color "bleed" between cells in exported ANSI

**Full changelog:** see [`CHANGELOG.md`](CHANGELOG.md).
