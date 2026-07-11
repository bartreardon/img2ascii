# Changelog

All notable changes to **Image 2 ASCII** are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] — 2026-07-11

The big addition in 1.1 is a full **interactive ASCII editor**, plus a pass to
make the app feel properly native on macOS (menus, keyboard, drag & drop,
Settings, and accessibility).

### Added

- **ASCII Editor** — a new *Editor* mode that turns the app into a text-based
  drawing tool:
  - **Tools:** Paint, Eraser, Line/Text, and rectangular Select.
  - **Line tool** draws box-drawing lines with the arrow keys, inserting the
    correct corner glyphs on turns (rounded / square / heavy / double styles),
    and types text.
  - **Cursor navigation in every tool:** arrow keys move a visible cursor;
    **Space** stamps the current glyph (Paint), **Delete** erases at the cursor,
    **Shift-arrow** extends a selection (Select).
  - **Glyph palettes** for shades, lines and symbols, a custom-glyph field, and
    a recently-used row.
  - **Selection** can be filled with a solid color or gradient (foreground and
    background independently) or cleared/deleted.
  - **Capture** the current image/text output into the canvas, start a **new
    canvas**, or **open** a text/ANSI file to edit.
  - **Canvas sizing:** editable width/height fields with steppers, draggable
    resize handles on the rulers, auto-grow when drawing past the edge, and a
    **Lock size** option.
  - Optional **character grid** and **column/row rulers**, adjustable **zoom**,
    and a **dark/light** canvas toggle.
  - **Undo/redo** with named actions.
- **Menu bar & keyboard shortcuts** — a real command model: File (New Canvas,
  Open Image, Open Text File, Export ANSI/Plain/PNG), Edit (Cut/Copy/Paste/
  Select All/Delete, plus Copy as ANSI/Plain/Image), and View (rulers, grid,
  zoom), all with standard shortcuts (⌘N, ⌘O, ⇧⌘O, ⌘E, ⇧⌘E, ⇧⌘C, ⌘±, ⌘0, …).
- **Settings window (⌘,)** — default color depth, ramp, preview font, and editor
  defaults (zoom, canvas background, grid/rulers), persisted across launches.
- **Drag & drop** — drag the generated banner out to Finder or another app (as
  PNG or text), drag a selection out of the editor, and drag text/ANSI files (or
  Finder text clippings) into the editor to import them.
- **Copy as image** — put the rendered banner on the clipboard as PNG/TIFF.
- **ANSI import** — open plain *or* ANSI-colored `.txt` files (and `motd`-style
  files) and edit them with colors intact.
- **Right-click menu** on the canvas (Cut/Copy/Paste/Delete/Select All).
- **Accessibility** — the canvas is exposed to VoiceOver, and icon-only controls
  have accessibility labels.

### Fixed

- Editor canvas glyph alignment: characters now sit exactly on the cell grid, so
  the cursor, drawing and mouse hit-testing all agree.
- Dark-mode canvas edge and accents are now visible.
- Text-clipping import extracts the actual text payload instead of importing the
  raw property-list bytes.
- Removed a color "bleed" where a stale foreground/background could carry into
  following cells in exported ANSI.

## [1.0.0]

Initial release.

### Added

- **Image → ASCII** — convert PNG, JPEG, WebP, HEIC, GIF, TIFF and BMP with
  terminal aspect-ratio handling; density ramps or custom characters (ordered by
  glyph coverage), solid-fill mode, invert, and transparent-edge cropping.
- **Text → ASCII** — FIGlet block letters (12 bundled fonts + custom `.flf`
  import) or text rasterized in any installed font.
- **Color** — monochrome, per-pixel, solid, or gradient, in 24-bit truecolor or
  256-color.
- **Decoration** — box borders with a title, solid/gradient backgrounds, and
  neofetch-style info text.
- **Live preview** with side-by-side light/dark comparison and font selection.
- **Export** — ANSI `.txt` (motd-ready), plain text, transparent-background PNG
  at a chosen resolution, and copy to clipboard.
