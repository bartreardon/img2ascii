//
//  PNGFileDocument.swift
//  Image 2 ASCII
//
//  Wraps pre-rendered PNG data for SwiftUI's `.fileExporter`.
//

import SwiftUI
import UniformTypeIdentifiers

struct PNGFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.png]

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
