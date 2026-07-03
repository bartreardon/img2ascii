//
//  RGBColor.swift
//  Image 2 ASCII
//
//  A plain, Sendable RGB color value used throughout the conversion core.
//  Stored as 0...1 components. Kept free of SwiftUI so the core stays pure;
//  a SwiftUI bridge is provided in an extension for the UI layer only.
//

import Foundation

nonisolated struct RGBColor: Codable, Sendable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r.clamped01
        self.g = g.clamped01
        self.b = b.clamped01
    }

    /// Convenience initializer from 0...255 integer components.
    init(r8: Int, g8: Int, b8: Int) {
        self.init(r: Double(r8) / 255.0, g: Double(g8) / 255.0, b: Double(b8) / 255.0)
    }

    var r8: Int { Int((r * 255).rounded()) }
    var g8: Int { Int((g * 255).rounded()) }
    var b8: Int { Int((b * 255).rounded()) }

    /// Rec.601 relative luminance, 0...1.
    var luminance: Double { 0.299 * r + 0.587 * g + 0.114 * b }

    static let white = RGBColor(r: 1, g: 1, b: 1)
    static let black = RGBColor(r: 0, g: 0, b: 0)

    /// Linear interpolation between two colors in sRGB space.
    static func lerp(_ a: RGBColor, _ b: RGBColor, _ t: Double) -> RGBColor {
        let t = t.clamped01
        return RGBColor(r: a.r + (b.r - a.r) * t,
                        g: a.g + (b.g - a.g) * t,
                        b: a.b + (b.b - a.b) * t)
    }
}

/// A color stop for a positional gradient.
nonisolated struct GradientStop: Codable, Sendable, Hashable, Identifiable {
    var id: UUID
    var location: Double   // 0...1
    var color: RGBColor

    init(id: UUID = UUID(), location: Double, color: RGBColor) {
        self.id = id
        self.location = location.clamped01
        self.color = color
    }
}

extension Double {
    nonisolated var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
}

extension Array where Element == GradientStop {
    /// Sample the gradient at position `t` (0...1), interpolating between the
    /// two bracketing stops. Stops are sorted by location before sampling.
    nonisolated func sample(at t: Double) -> RGBColor {
        guard !isEmpty else { return .white }
        let sorted = self.sorted { $0.location < $1.location }
        let t = t.clamped01
        if t <= sorted.first!.location { return sorted.first!.color }
        if t >= sorted.last!.location { return sorted.last!.color }
        for i in 0..<(sorted.count - 1) {
            let lo = sorted[i], hi = sorted[i + 1]
            if t >= lo.location && t <= hi.location {
                let span = hi.location - lo.location
                let local = span > 0 ? (t - lo.location) / span : 0
                return RGBColor.lerp(lo.color, hi.color, local)
            }
        }
        return sorted.last!.color
    }
}
