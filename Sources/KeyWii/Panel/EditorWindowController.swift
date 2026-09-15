import AppKit
import SwiftUI
import HotKey

/// Hosts the "Edit Layouts" view or settings in a real, standard,
/// resizable `NSWindow` — deliberately *not* `OverlayPanel`'s
/// non-activating, auto-hide-on-blur design. Editing is a deliberate
/// action where the user doesn't mind the app briefly gaining normal
/// window focus, and a real window lets native modals (`NSColorPanel`,
/// `NSOpenPanel`) work with zero special handling.
///
/// One instance is reused for both — its content view is simply swapped
/// per `show(title:content:)` call.
final class EditorWindowController: NSWindowController {
    private var escMonitor: Any?

    /// Consulted by the Esc monitor before it closes the window — content
    /// with its own nested "cancel" state (e.g. `HotKeySettingsView`
    /// recording a shortcut) sets this to intercept Esc for that instead.
    /// Return `true` to mean "I handled it, don't close."
    var escOverride: (() -> Bool)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show(title: String, content: AnyView) {
        escOverride = nil

        let hosting = NSHostingView(rootView: content)
        window?.contentView = hosting
        window?.title = title

        let fitting = hosting.fittingSize
        if fitting.width > 0, fitting.height > 0 {
            window?.setContentSize(fitting)
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        // Required: confirmed empirically that NSApp.isActive is still
        // false even right after a status-bar-menu click, so `.accessory`
        // app windows need this or they end up ordered front but never
        // truly key. This activation is a normal, unavoidable "app became
        // active" event — if a third-party KVM/input-sharing utility pops
        // its own UI in response, that's it reacting to an ordinary macOS
        // app switch, not something this call can avoid while keeping the
        // window interactive.
        NSApp.activate(ignoringOtherApps: true)
        installEscMonitor()
    }

    func closeWindow() {
        window?.close()
    }

    private func installEscMonitor() {
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                if self.escOverride?() != true {
                    self.closeWindow()
                }
                return nil
            }
            return event
        }
    }

    private func removeEscMonitor() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }
}

private struct EditorWindowControllerEnvironmentKey: EnvironmentKey {
    static let defaultValue: EditorWindowController? = nil
}

extension EnvironmentValues {
    /// The window hosting this content, so nested modal-like state (e.g.
    /// `HotKeySettingsView`'s shortcut recorder) can claim `escOverride`.
    var editorWindowController: EditorWindowController? {
        get { self[EditorWindowControllerEnvironmentKey.self] }
        set { self[EditorWindowControllerEnvironmentKey.self] = newValue }
    }
}

private struct HotKeyRecordingStartEnvironmentKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct HotKeyRecordingEndEnvironmentKey: EnvironmentKey {
    static let defaultValue: ((KeyCombo?) -> Void)? = nil
}

extension EnvironmentValues {
    /// Called by `HotKeySettingsView` when recording starts, so
    /// `AppDelegate` can pause the currently-registered global shortcut —
    /// otherwise pressing that same combo while recording fires the old
    /// Carbon-level hotkey handler before the keystroke ever reaches the
    /// recorder.
    var onHotKeyRecordingStart: (() -> Void)? {
        get { self[HotKeyRecordingStartEnvironmentKey.self] }
        set { self[HotKeyRecordingStartEnvironmentKey.self] = newValue }
    }

    /// Called when recording ends: with a combo if one was captured
    /// (register it as the new shortcut), or `nil` if canceled (just
    /// resume the paused one).
    var onHotKeyRecordingEnd: ((KeyCombo?) -> Void)? {
        get { self[HotKeyRecordingEndEnvironmentKey.self] }
        set { self[HotKeyRecordingEndEnvironmentKey.self] = newValue }
    }
}
