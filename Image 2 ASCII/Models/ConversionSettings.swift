//
//  ConversionSettings.swift
//  Image 2 ASCII
//
//  All user-tunable parameters for an image→ASCII conversion. A pure, Sendable,
//  Codable value type so it can cross actor boundaries and key a debounced task.
//

import Foundation

nonisolated struct ConversionSettings: Codable, Sendable, Hashable {

    /// Default vertical compression (terminal cells are ~2:1 tall:wide).
    static let defaultCharAspect: Double = 0.5

    // MARK: Generator
    /// Whether the source is an image or text.
    var generatorMode: GeneratorMode = .image
    /// Text to render in text mode.
    var textInput: String = "Hello"
    /// Blank rows/columns kept around trimmed text art (0 = tight crop).
    var textMargin: Int = 1
    /// Which text engine to use.
    var textEngine: TextEngine = .figlet
    /// Selected FIGlet font name (matches a bundled/imported font).
    var figletFontName: String = "Standard"
    /// Rasterized mode: font family ("" = system), point size, and bold flag.
    var rasterFontName: String = ""
    var rasterFontSize: Double = 72
    var rasterBold: Bool = true

    // MARK: Geometry
    /// Output width in characters.
    var columns: Int = 80
    /// Vertical compression to compensate for terminal cells being ~2:1 tall:wide.
    var charAspect: Double = defaultCharAspect

    // MARK: Characters
    var characterSetMode: CharacterSetMode = .auto
    /// Name of the built-in ramp used in `.auto` mode (see `CharacterRamp`).
    var rampName: String = CharacterRamp.standard.name
    /// User-supplied characters for `.custom` mode (light→dark order).
    var customCharacters: String = "#"
    /// Threshold (0...1) used when `customCharacters` is a single glyph (fill mode).
    var threshold: Double = 0.5
    /// Characters to remove from whichever ramp is active (auto or custom).
    var excludedCharacters: String = ""
    /// For multi-char custom sets: order glyphs by measured ink coverage
    /// (light → dark) instead of the typed order.
    var sortCustomByCoverage: Bool = true
    /// Implicitly map the brightest level to a blank space in custom ramps.
    var customImplyBlank: Bool = true
    /// Flip the luminance→glyph mapping (for light vs dark target backgrounds).
    var invert: Bool = false
    /// Fill every opaque pixel with a solid block, ignoring the ramp/threshold
    /// (color carries the image). Overlays any character mode.
    var solidFill: Bool = false
    /// Treat (nearly) transparent pixels as empty cells (spaces) rather than color.
    var transparentAsSpace: Bool = true
    /// Crop to the opaque bounding box, ignoring transparent padding around the art.
    var cropTransparent: Bool = false

    // MARK: Color
    var colorMode: ColorMode = .monochrome
    var colorDepth: ANSIColorDepth = .truecolor
    var solidColor: RGBColor = .white
    var gradientStops: [GradientStop] = GradientPreset.fire.stops
    var gradientAxis: GradientAxis = .vertical

    // MARK: Background
    var backgroundMode: BackgroundMode = .none
    var backgroundColor: RGBColor = .black
    var backgroundGradientStops: [GradientStop] = GradientPreset.ocean.stops
    var backgroundGradientAxis: GradientAxis = .vertical

    /// Resolved background fill for the grid.
    var gridBackground: GridBackground {
        switch backgroundMode {
        case .none:     return .none
        case .solid:    return .solid(backgroundColor)
        case .gradient: return .gradient(stops: backgroundGradientStops, axis: backgroundGradientAxis)
        }
    }

    // MARK: Border
    var borderStyle: BorderStyle = .none
    var borderTitle: String = ""
    /// When nil, the border uses the terminal's default color.
    var borderColor: RGBColor? = nil

    // MARK: Info text
    var sideTextPlacement: SideTextPlacement = .none
    /// Multi-line block of info text (one entry per line).
    var infoText: String = ""

    init() {}

    // MARK: Shared decoration helpers (used by both engines)

    func makeBorderSpec() -> BorderSpec? {
        borderStyle == .none ? nil : BorderSpec(style: borderStyle, title: borderTitle, color: borderColor)
    }

    /// Split info text into right-side and below-block lines per placement.
    func infoTextLines() -> (side: [String], extra: [String]) {
        guard !infoText.isEmpty else { return ([], []) }
        let lines = infoText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        switch sideTextPlacement {
        case .none:  return ([], [])
        case .right: return (lines, [])
        case .below: return ([], lines)
        }
    }
}

/// Built-in gradient presets offered in the UI.
nonisolated enum GradientPreset: String, CaseIterable, Identifiable, Sendable {
    case fire
    case ocean
    case mono
    case rainbow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fire:    return "Fire (green→red→blue)"
        case .ocean:   return "Ocean"
        case .mono:    return "Mono fade"
        case .rainbow: return "Rainbow"
        }
    }

    var stops: [GradientStop] {
        switch self {
        case .fire:
            // Mirrors the example motd: green → orange → red → blue.
            return [
                GradientStop(location: 0.00, color: RGBColor(r8: 0,   g8: 175, b8: 0)),
                GradientStop(location: 0.33, color: RGBColor(r8: 255, g8: 175, b8: 0)),
                GradientStop(location: 0.50, color: RGBColor(r8: 215, g8: 95,  b8: 0)),
                GradientStop(location: 0.66, color: RGBColor(r8: 215, g8: 0,   b8: 0)),
                GradientStop(location: 1.00, color: RGBColor(r8: 0,   g8: 0,   b8: 255)),
            ]
        case .ocean:
            return [
                GradientStop(location: 0.0, color: RGBColor(r8: 0,  g8: 255, b8: 200)),
                GradientStop(location: 0.5, color: RGBColor(r8: 0,  g8: 135, b8: 255)),
                GradientStop(location: 1.0, color: RGBColor(r8: 90, g8: 0,   b8: 255)),
            ]
        case .mono:
            return [
                GradientStop(location: 0.0, color: RGBColor(r8: 80,  g8: 80,  b8: 80)),
                GradientStop(location: 1.0, color: RGBColor(r8: 255, g8: 255, b8: 255)),
            ]
        case .rainbow:
            return [
                GradientStop(location: 0.00, color: RGBColor(r8: 255, g8: 0,   b8: 0)),
                GradientStop(location: 0.25, color: RGBColor(r8: 255, g8: 200, b8: 0)),
                GradientStop(location: 0.50, color: RGBColor(r8: 0,   g8: 200, b8: 0)),
                GradientStop(location: 0.75, color: RGBColor(r8: 0,   g8: 160, b8: 255)),
                GradientStop(location: 1.00, color: RGBColor(r8: 160, g8: 0,   b8: 255)),
            ]
        }
    }
}
