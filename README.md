# Image 2 ASCII

A native macOS app that turns **images and text into colored ASCII-art banners**
for the terminal — ideal for a login `motd`, a script header, or a README badge.

## Features

- **Image → ASCII** — open PNG, JPEG, WebP, HEIC, GIF, TIFF or BMP and convert to
  ASCII with correct terminal aspect-ratio handling.
  - Density ramps (Standard, Detailed, Blocks, Binary) or your own custom
    characters, with automatic ordering by glyph coverage.
  - **Solid fill** mode: every opaque pixel becomes a colored block, so the image's
    own colors carry it (transparent areas stay blank).
  - Invert, transparent-as-blank, and crop-transparent-edges options.
- **Text → ASCII**
  - **FIGlet** block letters — 12 bundled fonts, plus import any `.flf` file.
  - **Rasterized** — render text in *any installed font* (Nerd Fonts included),
    then convert like an image.
- **Color** — monochrome, per-pixel from the image, a single solid color, or a
  positional gradient — in 24-bit **truecolor** or **256-color**.
- **Decoration** — box borders with an embedded title, a solid or gradient banner
  background, and neofetch-style info text beside or below the art.
- **Live preview** — compare the output against **light and dark** terminal
  backgrounds side by side, choose the display font, and zoom.
- **Export** — colored ANSI `.txt` (raw escape codes, motd-ready), plain `.txt`,
  a **transparent-background PNG** at a chosen resolution, or copy to the clipboard.

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 (to build)

## Build & run

Open `Image 2 ASCII.xcodeproj` in Xcode and run, or from the command line:

```sh
xcodebuild -project "Image 2 ASCII.xcodeproj" \
  -scheme "Image 2 ASCII" -configuration Debug build
```

## Usage

1. Choose **Image** or **Text** mode.
2. *Image:* drop or open a file. *Text:* type your text and pick a FIGlet or
   rasterized font.
3. Adjust characters, color, border, background and info text in the sidebar.
4. Compare on light/dark, then **Export** (ANSI / plain / PNG) or **Copy**.

To use an ANSI export as a login banner, save it and reference it from your shell
profile or `/etc/motd`.

## FIGlet fonts

Bundled fonts come from the standard, freely-redistributable FIGlet set — see
`Image 2 ASCII/Fonts/CREDITS.txt`. Add more via **Import .flf font…** in the
FIGlet font picker (stored in Application Support).

## Architecture

A pure, `nonisolated` core produces a structured `ASCIIGrid`; the ANSI exporter,
the SwiftUI preview and the PNG renderer all consume that same grid. Conversion
runs off the main thread and is debounced.

## License

_TBD._
