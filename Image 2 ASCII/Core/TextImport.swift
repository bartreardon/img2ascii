//
//  TextImport.swift
//  Image 2 ASCII
//
//  Reads text out of a dropped/opened file. Plain-text files decode directly;
//  Finder ".textClipping" files (and other binary-plist wrappers) are unwrapped
//  to their plain-text payload instead of importing the plist bytes verbatim.
//  Pure & nonisolated.
//

import Foundation

nonisolated enum TextImport {

    static func text(fromFileAt url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if url.pathExtension.lowercased() == "textclipping" || isBinaryPlist(data) {
            if let unwrapped = textFromClipping(data) { return unwrapped }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
    }

    static func text(fromData data: Data, extension ext: String) -> String? {
        if ext.lowercased() == "textclipping" || isBinaryPlist(data) {
            if let unwrapped = textFromClipping(data) { return unwrapped }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
    }

    private static func isBinaryPlist(_ data: Data) -> Bool {
        data.prefix(8).elementsEqual(Array("bplist00".utf8))
    }

    /// Pull the plain-text payload out of a text-clipping plist.
    private static func textFromClipping(_ data: Data) -> String? {
        guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return nil }

        var payloads: [String: Data] = [:]
        collect(obj, into: &payloads)

        // Prefer UTF-8 plain text, then other plain-text representations.
        let priority = ["public.utf8-plain-text", "public.plain-text",
                        "public.utf16-plain-text", "public.utf16-external-plain-text", "public.text"]
        for uti in priority {
            guard let d = payloads[uti] else { continue }
            let encoding: String.Encoding = uti.contains("utf16") ? .utf16 : .utf8
            if let s = String(data: d, encoding: encoding) ?? String(data: d, encoding: .utf8) {
                return s
            }
        }
        return nil
    }

    /// Walk the plist collecting every UTI→Data pair, in either the
    /// `{ uti: data }` or `{ "UTI": uti, "Data": data }` shape.
    private static func collect(_ any: Any, into payloads: inout [String: Data]) {
        if let dict = any as? [String: Any] {
            for (key, value) in dict where key.hasPrefix("public.") || key.hasPrefix("com.") {
                if let d = value as? Data { payloads[key] = d }
            }
            if let uti = dict["UTI"] as? String, let d = dict["Data"] as? Data {
                payloads[uti] = d
            }
            for value in dict.values { collect(value, into: &payloads) }
        } else if let array = any as? [Any] {
            for element in array { collect(element, into: &payloads) }
        }
    }
}
