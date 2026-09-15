import Foundation
import HotKey

/// Persists the user's chosen global shortcut in `UserDefaults` — this is
/// an app-level runtime preference, not keyboard reference data, so it
/// deliberately doesn't live in `KeyWiiDocument`/`document.json`.
///
/// Lives in `App/`, not `Models/`, since `KeyCombo` pulls in AppKit —
/// `Models/` stays platform-plain per CLAUDE.md's conventions.
enum HotKeyPreference {
    private static let defaultsKey = "KeyWiiHotKeyCombo"

    static let `default` = KeyCombo(key: .space, modifiers: [.option])

    static var current: KeyCombo {
        get {
            guard let dict = UserDefaults.standard.dictionary(forKey: defaultsKey),
                  let combo = KeyCombo(dictionary: dict)
            else { return Self.default }
            return combo
        }
        set {
            UserDefaults.standard.set(newValue.dictionary, forKey: defaultsKey)
        }
    }
}
