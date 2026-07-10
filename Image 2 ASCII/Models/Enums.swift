//
//  Enums.swift
//  Image 2 ASCII
//
//  Shared enumerations used across the conversion settings, engine and renderers.
//  These are pure value types and must stay free of any UI / actor isolation so
//  the conversion core can run off the main thread.
//

import Foundation

/// How glyphs are chosen for each cell.
nonisolated enum CharacterSetMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Use a built-in density-ordered ramp to best represent shape & fill.
    case auto
    /// Use the user-supplied characters (one = threshold fill, many = custom ramp).
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:   return "Auto (best fit)"
        case .custom: return "Custom characters"
        }
    }
}

/// How each cell is colored.
nonisolated enum ColorMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// No color codes emitted — plain density characters.
    case monochrome
    /// Sample each cell's color from the source image.
    case perPixel
    /// One fixed foreground color for the whole banner.
    case solid
    /// A positional color gradient across the art.
    case gradient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .perPixel:   return "Image colors"
        case .solid:      return "Solid color"
        case .gradient:   return "Gradient"
        }
    }
}

/// ANSI color encoding used in the exported escape codes.
nonisolated enum ANSIColorDepth: String, Codable, Sendable, CaseIterable, Identifiable {
    /// 24-bit truecolor: `\e[38;2;r;g;bm`.
    case truecolor
    /// 256-color palette: `\e[38;5;Nm`.
    case ansi256

    var id: String { rawValue }

    var label: String {
        switch self {
        case .truecolor: return "Truecolor (24-bit)"
        case .ansi256:   return "256-color"
        }
    }
}

/// Box-drawing border styles.
nonisolated enum BorderStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case rounded
    case square
    case heavy
    case double

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:    return "None"
        case .rounded: return "Rounded"
        case .square:  return "Square"
        case .heavy:   return "Heavy"
        case .double:  return "Double"
        }
    }

    /// Corner / edge glyphs: (topLeft, topRight, bottomLeft, bottomRight, horizontal, vertical).
    var glyphs: (tl: Character, tr: Character, bl: Character, br: Character, h: Character, v: Character)? {
        switch self {
        case .none:    return nil
        case .rounded: return ("╭", "╮", "╰", "╯", "─", "│")
        case .square:  return ("┌", "┐", "└", "┘", "─", "│")
        case .heavy:   return ("┏", "┓", "┗", "┛", "━", "┃")
        case .double:  return ("╔", "╗", "╚", "╝", "═", "║")
        }
    }
}

/// Direction a gradient is interpolated along.
nonisolated enum GradientAxis: String, Codable, Sendable, CaseIterable, Identifiable {
    case vertical
    case horizontal
    case diagonal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vertical:   return "Vertical"
        case .horizontal: return "Horizontal"
        case .diagonal:   return "Diagonal"
        }
    }
}

/// Banner background fill.
nonisolated enum BackgroundMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case solid
    case gradient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:     return "None"
        case .solid:    return "Solid"
        case .gradient: return "Gradient"
        }
    }
}

/// Which kind of artwork the app is generating.
nonisolated enum GeneratorMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case image
    case text
    case editor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .image:  return "Image"
        case .text:   return "Text"
        case .editor: return "Editor"
        }
    }
}

/// How text is turned into ASCII art.
nonisolated enum TextEngine: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Hollow block letters from a bundled/imported FIGlet (.flf) font.
    case figlet
    /// Rasterize text in any installed font, then run the image→ASCII engine.
    case rasterized

    var id: String { rawValue }

    var label: String {
        switch self {
        case .figlet:     return "FIGlet font"
        case .rasterized: return "Rasterized font"
        }
    }
}

/// Where neofetch-style info text is placed relative to the art.
nonisolated enum SideTextPlacement: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case right
    case below

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:  return "None"
        case .right: return "To the right"
        case .below: return "Below"
        }
    }
}
