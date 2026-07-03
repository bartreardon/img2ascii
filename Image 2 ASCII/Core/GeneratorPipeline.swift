//
//  GeneratorPipeline.swift
//  Image 2 ASCII
//
//  Single nonisolated entry point that turns the current settings (+ optional
//  loaded image) into an ASCIIGrid, dispatching to the image engine, the text
//  rasterizer, or the FIGlet engine. Everything downstream (ANSI export,
//  preview) consumes the resulting grid uniformly.
//

import Foundation

nonisolated enum GeneratorPipeline {

    static func makeGrid(settings: ConversionSettings, imageBuffer: PixelBuffer?) -> ASCIIGrid {
        switch settings.generatorMode {
        case .image:
            guard let buffer = imageBuffer else { return .empty }
            return ConversionEngine.convert(buffer, settings: settings)

        case .text:
            var grid: ASCIIGrid
            switch settings.textEngine {
            case .rasterized:
                guard let buffer = TextRasterizer.makeBuffer(text: settings.textInput,
                                                             fontName: settings.rasterFontName,
                                                             size: settings.rasterFontSize,
                                                             bold: settings.rasterBold)
                else { return .empty }
                grid = ConversionEngine.convert(buffer, settings: settings)

            case .figlet:
                grid = FigletEngine.render(settings: settings)
            }
            // Trim the empty space around the text and apply a uniform margin.
            grid.cells = GridTrim.trim(grid.cells, margin: settings.textMargin)
            return grid
        }
    }
}
