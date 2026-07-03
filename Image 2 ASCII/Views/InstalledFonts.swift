//
//  InstalledFonts.swift
//  Image 2 ASCII
//
//  All installed font families, for the rasterized text engine's family picker.
//

import AppKit

enum InstalledFonts {
    static let families: [String] = NSFontManager.shared.availableFontFamilies.sorted()
}
