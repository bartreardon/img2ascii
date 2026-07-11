//
//  AppCommands.swift
//  Image 2 ASCII
//
//  The menu-bar command model. Commands act on the focused window's AppModel,
//  published via `.focusedSceneValue`. Every important action is reachable from
//  the menu bar with a standard shortcut, mirroring the toolbar/sidebar.
//

import SwiftUI

struct AppModelFocusedKey: FocusedValueKey {
    typealias Value = AppModel
}

extension FocusedValues {
    var appModel: AppModel? {
        get { self[AppModelFocusedKey.self] }
        set { self[AppModelFocusedKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.appModel) private var model

    private var isEditor: Bool { model?.settings.generatorMode == .editor }

    var body: some Commands {
        // File ▸ New / Open
        CommandGroup(replacing: .newItem) {
            Button("New Canvas") { model?.newEditorCanvas() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model == nil)
            Divider()
            Button("Open Image…") { model?.openImage() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(model == nil)
            Button("Open Text File…") { model?.openEditorFile() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model == nil)
        }

        // File ▸ Export
        CommandGroup(replacing: .importExport) {
            Button("Export ANSI (Colored)…") { model?.exportText(colored: true) }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(model?.hasOutput != true)
            Button("Export Plain Text…") { model?.exportText(colored: false) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model?.hasOutput != true)
            Button("Export PNG…") { model?.showPNGSheet = true }
                .disabled(model?.hasOutput != true)
        }

        // Edit ▸ Copy as…
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy as ANSI") { model?.copyText(colored: true) }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(model?.hasOutput != true)
            Button("Copy as Plain Text") { model?.copyText(colored: false) }
                .disabled(model?.hasOutput != true)
            Button("Copy as Image") { model?.copyImage() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model?.hasOutput != true)
        }

        // View ▸ editor view options
        CommandGroup(after: .toolbar) {
            Button(model?.editor.showRulers == true ? "Hide Rulers" : "Show Rulers") {
                model?.editor.showRulers.toggle()
            }
            .keyboardShortcut("r", modifiers: [.command, .control])
            .disabled(!isEditor)

            Button(model?.editor.showGrid == true ? "Hide Grid" : "Show Grid") {
                model?.editor.showGrid.toggle()
            }
            .keyboardShortcut("g", modifiers: [.command, .control])
            .disabled(!isEditor)

            Divider()
            Button("Zoom In") { zoom(+1) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!isEditor)
            Button("Zoom Out") { zoom(-1) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!isEditor)
            Button("Actual Size") { model?.editor.fontSize = 14 }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!isEditor)
        }
    }

    private func zoom(_ delta: Double) {
        guard let editor = model?.editor else { return }
        editor.fontSize = min(32, max(6, editor.fontSize + delta))
    }
}
