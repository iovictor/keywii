import AppKit
import SwiftUI
import HotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = DocumentStore()
    private let shelfAppearance = ShelfAppearanceStore()
    private var panel: OverlayPanel!
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!
    private let editorWindow = EditorWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, no Cmd-Tab entry — pure background utility. The
        // status bar icon (below) is the only always-visible affordance,
        // and exists specifically so there's a way to quit without a
        // terminal.
        NSApp.setActivationPolicy(.accessory)

        panel = OverlayPanel(store: store, appearance: shelfAppearance)
        registerHotKey(HotKeyPreference.current)
        setUpStatusItem()
        setUpEditMenu()
    }

    /// A minimal, never-visually-prominent Edit menu — just enough for
    /// `performKeyEquivalent` to recognize Cmd-C/V/X/A and route them to
    /// the focused text field's `copy:`/`paste:`/etc. This app has no
    /// window/app menu otherwise (`.accessory`, no Dock icon), but without
    /// *any* main menu at all, standard text-editing keyboard shortcuts
    /// silently don't work in any `TextField` across the app — AppKit
    /// checks the main menu for a matching key equivalent before a
    /// text view's own key-binding interpretation ever runs.
    private func setUpEditMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit KeyWii", action: #selector(quit), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func showLayoutEditor() {
        editorWindow.show(title: "Edit Layouts", content: AnyView(LayoutEditorView(store: store)))
    }

    private func showSettings() {
        let onRecordingStart: () -> Void = { [weak self] in self?.hotKey.isPaused = true }
        let onRecordingEnd: (KeyCombo?) -> Void = { [weak self] combo in
            guard let self else { return }
            if let combo {
                self.registerHotKey(combo)
            } else {
                self.hotKey.isPaused = false
            }
        }

        let content = HotKeySettingsView(appearance: shelfAppearance)
            .environment(\.editorWindowController, editorWindow)
            .environment(\.onHotKeyRecordingStart, onRecordingStart)
            .environment(\.onHotKeyRecordingEnd, onRecordingEnd)
        editorWindow.show(title: "Settings", content: AnyView(content))
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "square.grid.3x2",
            accessibilityDescription: "KeyWii"
        )

        let menu = NSMenu()
        menu.addItem(withTitle: "Show KeyWii", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Edit Layouts…", action: #selector(openLayoutEditor), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit KeyWii", action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
    }

    @objc private func togglePanel() {
        panel.toggle()
    }

    @objc private func openLayoutEditor() {
        showLayoutEditor()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// (Re-)registers the global shortcut and persists it, so a change made
    /// via the in-panel settings takes effect immediately and survives
    /// relaunch. `HotKey.keyCombo` is immutable, so changing shortcuts means
    /// replacing the whole `HotKey` instance — its `deinit` unregisters the
    /// old Carbon hotkey automatically.
    private func registerHotKey(_ combo: KeyCombo) {
        HotKeyPreference.current = combo
        hotKey = HotKey(keyCombo: combo)
        hotKey.keyDownHandler = { [weak self] in
            self?.panel.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }
}
