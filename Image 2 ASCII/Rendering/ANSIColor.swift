//
//  ANSIColor.swift
//  Image 2 ASCII
//
//  Converts RGBColor into ANSI SGR parameter strings, for both 24-bit truecolor
//  and the xterm 256-color palette (6×6×6 cube + 24-step grayscale, nearest).
//  Pure & nonisolated.
//

import Foundation

nonisolated enum ANSIColor {

    private static let cubeLevels = [0, 95, 135, 175, 215, 255]

    /// SGR parameter for a foreground color (e.g. "38;2;255;0;0" or "38;5;196").
    static func foregroundParams(_ color: RGBColor, depth: ANSIColorDepth) -> String {
        switch depth {
        case .truecolor: return "38;2;\(color.r8);\(color.g8);\(color.b8)"
        case .ansi256:   return "38;5;\(index256(color))"
        }
    }

    /// SGR parameter for a background color.
    static func backgroundParams(_ color: RGBColor, depth: ANSIColorDepth) -> String {
        switch depth {
        case .truecolor: return "48;2;\(color.r8);\(color.g8);\(color.b8)"
        case .ansi256:   return "48;5;\(index256(color))"
        }
    }

    /// Map an RGB color to the nearest xterm-256 palette index.
    static func index256(_ color: RGBColor) -> Int {
        let r = color.r8, g = color.g8, b = color.b8

        // Nearest color-cube entry.
        let qr = nearestCubeIndex(r)
        let qg = nearestCubeIndex(g)
        let qb = nearestCubeIndex(b)
        let cubeIndex = 16 + 36 * qr + 6 * qg + qb
        let cubeColor = (cubeLevels[qr], cubeLevels[qg], cubeLevels[qb])
        let cubeDist = dist(r, g, b, cubeColor.0, cubeColor.1, cubeColor.2)

        // Nearest grayscale ramp entry (indices 232...255 → values 8,18,…,238).
        let grayAvg = (r + g + b) / 3
        var grayIdx = Int((Double(grayAvg) - 8) / 10 + 0.5)
        grayIdx = min(23, max(0, grayIdx))
        let grayVal = 8 + 10 * grayIdx
        let grayDist = dist(r, g, b, grayVal, grayVal, grayVal)

        return grayDist < cubeDist ? (232 + grayIdx) : cubeIndex
    }

    private static func nearestCubeIndex(_ v: Int) -> Int {
        var best = 0, bestDist = Int.max
        for (i, level) in cubeLevels.enumerated() {
            let d = abs(level - v)
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }

    private static func dist(_ r1: Int, _ g1: Int, _ b1: Int, _ r2: Int, _ g2: Int, _ b2: Int) -> Int {
        let dr = r1 - r2, dg = g1 - g2, db = b1 - b2
        return dr * dr + dg * dg + db * db
    }
}
