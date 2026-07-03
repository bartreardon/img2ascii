//
//  TextFileDocument.swift
//  Image 2 ASCII
//
//  A minimal plain-text FileDocument used with SwiftUI's `.fileExporter`. The
//  text is UTF-8 encoded, which preserves both the box-drawing Unicode glyphs and
//  the raw ESC (0x1B) bytes in colored exports.
//

import SwiftUI
import UniformTypeIdentifiers

struct TextFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
