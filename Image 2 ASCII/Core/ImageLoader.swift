//
//  ImageLoader.swift
//  Image 2 ASCII
//
//  Loads an image file (PNG/JPEG/WebP/HEIC/TIFF…) via ImageIO and normalizes it
//  into a known RGBA8 sRGB PixelBuffer by drawing once into a self-owned context.
//  Pure & nonisolated.
//

import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

nonisolated enum ImageLoaderError: LocalizedError {
    case cannotCreateSource
    case cannotDecode
    case cannotCreateContext

    var errorDescription: String? {
        switch self {
        case .cannotCreateSource: return "Could not read the image file."
        case .cannotDecode:       return "The image format is not supported or the file is corrupt."
        case .cannotCreateContext: return "Could not prepare the image for conversion."
        }
    }
}

nonisolated enum ImageLoader {

    /// Content types accepted by the open/import panel.
    static let supportedContentTypes: [UTType] = {
        var types: [UTType] = [.png, .jpeg, .gif, .bmp, .tiff, .heic, .image]
        if let webp = UTType("org.webmproject.webp") { types.append(webp) }
        return types
    }()

    /// Load and decode a `CGImage` from a file URL.
    static func loadCGImage(from url: URL) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoaderError.cannotCreateSource
        }
        let options: [CFString: Any] = [kCGImageSourceShouldCache: true]
        guard let image = CGImageSourceCreateImageAtIndex(src, 0, options as CFDictionary) else {
            throw ImageLoaderError.cannotDecode
        }
        return image
    }

    /// Decode `data` (e.g. from a drag-drop) into a `CGImage`.
    static func loadCGImage(from data: Data) throws -> CGImage {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageLoaderError.cannotCreateSource
        }
        guard let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw ImageLoaderError.cannotDecode
        }
        return image
    }

    /// Draw a `CGImage` into a guaranteed RGBA8 sRGB buffer and wrap it.
    static func pixelBuffer(from cgImage: CGImage) throws -> PixelBuffer {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ImageLoaderError.cannotCreateContext
        }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // Draw inside the closure: the context's backing pointer is only valid here.
        let ok: Bool = data.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(data: base,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo)
            else { return false }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { throw ImageLoaderError.cannotCreateContext }

        return PixelBuffer(width: width, height: height, pixels: data)
    }

    /// Convenience: URL → PixelBuffer.
    static func pixelBuffer(from url: URL) throws -> PixelBuffer {
        try pixelBuffer(from: loadCGImage(from: url))
    }
}
