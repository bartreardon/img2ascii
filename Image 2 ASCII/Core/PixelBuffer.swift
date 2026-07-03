//
//  PixelBuffer.swift
//  Image 2 ASCII
//
//  A tightly-packed RGBA8 sRGB pixel buffer with a cell-averaging sampler.
//  Pure & nonisolated so it can be crunched off the main thread.
//

import Foundation

nonisolated struct PixelBuffer: Sendable {
    let width: Int
    let height: Int
    /// RGBA8, row-major, length == width * height * 4.
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Average of a sub-rectangle. Coordinates are clamped to bounds.
    /// Returns components in 0...1 plus Rec.601 luminance (0...1).
    /// Alpha-weights the color so transparent pixels don't darken the average.
    func averageCell(x0: Int, y0: Int, x1: Int, y1: Int) -> (r: Double, g: Double, b: Double, a: Double, luma: Double) {
        let xs = max(0, min(x0, width))
        let ys = max(0, min(y0, height))
        let xe = max(xs + 1, min(x1, width))
        let ye = max(ys + 1, min(y1, height))

        var rSum = 0.0, gSum = 0.0, bSum = 0.0, aSum = 0.0
        var weight = 0.0
        var count = 0.0

        for y in ys..<ye {
            let rowBase = y * width * 4
            for x in xs..<xe {
                let i = rowBase + x * 4
                let a = Double(pixels[i + 3]) / 255.0
                rSum += Double(pixels[i + 0]) / 255.0 * a
                gSum += Double(pixels[i + 1]) / 255.0 * a
                bSum += Double(pixels[i + 2]) / 255.0 * a
                aSum += a
                weight += a
                count += 1
            }
        }

        guard count > 0 else { return (0, 0, 0, 0, 0) }
        let avgA = aSum / count
        // Normalize color by accumulated alpha weight (premultiplied → straight).
        let r = weight > 0 ? rSum / weight : 0
        let g = weight > 0 ? gSum / weight : 0
        let b = weight > 0 ? bSum / weight : 0
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        return (r, g, b, avgA, luma)
    }

    /// Bounding box of pixels whose alpha exceeds `alphaThreshold` (0...1).
    /// Returns nil if the image is fully transparent.
    func opaqueBounds(alphaThreshold: Double) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        let aMin = UInt8(max(0, min(255, (alphaThreshold * 255).rounded())))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let rowBase = y * width * 4
            for x in 0..<width {
                if pixels[rowBase + x * 4 + 3] > aMin {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return (minX, minY, maxX, maxY)
    }
}
