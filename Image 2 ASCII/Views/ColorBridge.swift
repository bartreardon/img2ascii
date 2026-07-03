//
//  ColorBridge.swift
//  Image 2 ASCII
//
//  Bridges the pure RGBColor value type to SwiftUI Color for color pickers.
//  UI layer only.
//

import SwiftUI
import AppKit

extension RGBColor {
    /// Construct from a SwiftUI Color by resolving through sRGB.
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        self.init(r: Double(ns.redComponent),
                  g: Double(ns.greenComponent),
                  b: Double(ns.blueComponent))
    }
}

extension Binding where Value == RGBColor {
    /// A `Binding<Color>` view over an `RGBColor` binding, for `ColorPicker`.
    var asColor: Binding<Color> {
        Binding<Color>(
            get: { self.wrappedValue.color },
            set: { self.wrappedValue = RGBColor($0) }
        )
    }
}
