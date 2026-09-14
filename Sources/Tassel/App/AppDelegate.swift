import AppKit
import HotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = DocumentStore()
    private var panel: OverlayPanel!
    private var hotKey: HotKey!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, no menu bar app switcher entry — pure background utility.
        NSApp.setActivationPolicy(.accessory)

        panel = OverlayPanel(store: store)

        // Default shortcut: Option + Space. Change here for now;
        // move to a user-configurable shortcut recorder later.
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey.keyDownHandler = { [weak self] in
            self?.panel.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }
}
