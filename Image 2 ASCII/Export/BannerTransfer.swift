//
//  BannerTransfer.swift
//  Image 2 ASCII
//
//  A Transferable wrapper so the current output can be dragged out of the app —
//  to Finder or another app — as a PNG (image apps / Finder) or as plain text
//  (editors, Terminal). Representations render lazily when the drop resolves.
//

import SwiftUI
import UniformTypeIdentifiers

struct BannerTransfer: Transferable {
    let grid: ASCIIGrid
    let depth: ANSIColorDepth

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { banner in
            PNGRenderer.render(grid: banner.grid, fontSize: 16, defaultColor: .white) ?? Data()
        }
        .suggestedFileName("banner.png")

        DataRepresentation(exportedContentType: .plainText) { banner in
            Data(ANSIRenderer.render(banner.grid, depth: banner.depth, colored: false).utf8)
        }
        .suggestedFileName("banner.txt")

        ProxyRepresentation { banner in
            ANSIRenderer.render(banner.grid, depth: banner.depth, colored: false)
        }
    }
}
