//
//  DualPreviewView.swift
//  Image 2 ASCII
//
//  The preview area. Renders the attributed output in a monospaced font and lets
//  the user compare it against light and dark terminal backgrounds (side by side
//  or one at a time). Per-glyph colors render identically in any appearance; only
//  the backing surface changes, and uncolored text adapts to the pane's scheme.
//

import SwiftUI
import AppKit

/// Monospaced fonts available for the preview. Output export is unaffected — this
/// only changes how the art is displayed, for comparing fixed-width / Nerd Fonts.
enum PreviewFont {
    /// Sentinel for the system monospaced design font.
    static let system = "__system__"

    static let names: [String] = {
        var result: [String] = []
        for family in NSFontManager.shared.availableFontFamilies {
            if let font = NSFont(name: family, size: 12), font.isFixedPitch {
                result.append(family)
            }
        }
        return result.sorted()
    }()
}

enum PreviewBackgroundMode: String, CaseIterable, Identifiable {
    case dark, light, split
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark:  return "Dark"
        case .light: return "Light"
        case .split: return "Split"
        }
    }
}

struct DualPreviewView: View {
    let text: AttributedString
    let isEmpty: Bool

    @State private var mode: PreviewBackgroundMode = .dark
    @State private var fontSize: Double = 9
    @AppStorage("previewFontName") private var fontName: String = PreviewFont.system

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Background", selection: $mode) {
                    ForEach(PreviewBackgroundMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 240)

                Picker("Font", selection: $fontName) {
                    Text("System Mono").tag(PreviewFont.system)
                    Divider()
                    ForEach(PreviewFont.names, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 190)

                Spacer()

                Image(systemName: "textformat.size.smaller")
                    .foregroundStyle(.secondary)
                Slider(value: $fontSize, in: 5...20)
                    .frame(width: 120)
                Image(systemName: "textformat.size.larger")
                    .foregroundStyle(.secondary)
            }
            .padding(8)

            Divider()

            Group {
                if isEmpty {
                    ContentUnavailableView("No output yet",
                                           systemImage: "character.textbox",
                                           description: Text("Open an image to generate ASCII art."))
                } else {
                    switch mode {
                    case .dark:  pane(.dark)
                    case .light: pane(.light)
                    case .split:
                        HStack(spacing: 0) {
                            pane(.dark)
                            Divider()
                            pane(.light)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func pane(_ scheme: ColorScheme) -> some View {
        PreviewPane(text: text,
                    background: baseColor(scheme),
                    scheme: scheme,
                    fontName: fontName,
                    fontSize: fontSize)
    }

    private func baseColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.09, green: 0.09, blue: 0.11) : Color(red: 0.98, green: 0.98, blue: 0.97)
    }
}

struct PreviewPane: View {
    let text: AttributedString
    let background: Color
    let scheme: ColorScheme
    let fontName: String
    let fontSize: Double

    private var resolvedFont: Font {
        fontName == PreviewFont.system
            ? .system(size: fontSize, design: .monospaced)
            : .custom(fontName, size: fontSize)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(resolvedFont)
                .lineSpacing(0)
                .monospacedDigit()
                .textSelection(.enabled)
                .fixedSize()
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .environment(\.colorScheme, scheme)
    }
}
