//
//  CharacterRamp.swift
//  Image 2 ASCII
//
//  Density-ordered character ramps used to map luminance to glyphs. Ramps are
//  ordered light→dark (index 0 = brightest/lightest glyph). Pure & nonisolated.
//

import Foundation

nonisolated struct CharacterRamp: Sendable, Identifiable, Hashable {
    let name: String
    /// Characters ordered light → dark (index 0 represents the brightest area).
    let characters: [Character]

    var id: String { name }

    init(name: String, _ string: String) {
        self.name = name
        self.characters = Array(string)
    }

    init(name: String, characters: [Character]) {
        self.name = name
        self.characters = characters
    }

    /// A copy with the given characters removed. If removal would empty the ramp,
    /// the original is kept.
    func removing(_ excluded: Set<Character>) -> CharacterRamp {
        guard !excluded.isEmpty else { return self }
        let filtered = characters.filter { !excluded.contains($0) }
        return CharacterRamp(name: name, characters: filtered.isEmpty ? characters : filtered)
    }

    /// A copy with blank/space characters removed, so every level is visible
    /// (used by solid fill). Falls back to a block if nothing remains.
    func removingSpaces() -> CharacterRamp {
        let filtered = characters.filter { $0 != " " }
        return CharacterRamp(name: name, characters: filtered.isEmpty ? ["█"] : filtered)
    }

    /// Map a normalized brightness (0 = dark, 1 = bright) to a glyph.
    /// `index 0` is the lightest glyph, so brighter input picks lower indices.
    func glyph(forBrightness brightness: Double) -> Character {
        guard !characters.isEmpty else { return " " }
        let b = brightness.clamped01
        // brightness 1 -> lightest glyph (index 0); brightness 0 -> darkest (last).
        let idx = Int(((1 - b) * Double(characters.count - 1)).rounded())
        return characters[Swift.min(Swift.max(0, idx), characters.count - 1)]
    }

    // MARK: Built-ins

    /// Short 10-level ramp (jp2a-style), light → dark.
    static let standard = CharacterRamp(name: "Standard", " .:-=+*#%@")

    /// Long 70-level ramp for finer detail, light → dark.
    static let detailed = CharacterRamp(
        name: "Detailed",
        "  .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"
    )

    /// Block-shading ramp, light → dark.
    static let blocks = CharacterRamp(name: "Blocks", " ░▒▓█")

    /// Minimal two-tone ramp.
    static let binary = CharacterRamp(name: "Binary", " #")

    static let allBuiltins: [CharacterRamp] = [.standard, .detailed, .blocks, .binary]

    static func named(_ name: String) -> CharacterRamp {
        allBuiltins.first { $0.name == name } ?? .standard
    }
}
