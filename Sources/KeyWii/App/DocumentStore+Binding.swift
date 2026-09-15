import SwiftUI

/// A SwiftUI `Binding` extension on `DocumentStore`, kept out of `Models/`
/// — that layer stays platform-plain per CLAUDE.md's conventions.
extension DocumentStore {
    /// Live binding into `document` for one key, identified by its stable
    /// `slotID` (not array index, which can shift). Every write through
    /// this binding persists immediately. Shared by `PanelContentView`
    /// (tap-to-edit) and `AppDelegate` (opens the same key in the editor
    /// window).
    func keyBinding(layoutID: UUID, slotID: String) -> Binding<KeyLayout>? {
        guard let layoutIndex = document.layouts.firstIndex(where: { $0.id == layoutID }),
              let keyIndex = document.layouts[layoutIndex].keys.firstIndex(where: { $0.slotID == slotID })
        else { return nil }

        return Binding(
            get: { self.document.layouts[layoutIndex].keys[keyIndex] },
            set: { newValue in
                self.document.layouts[layoutIndex].keys[keyIndex] = newValue
                self.save()
            }
        )
    }
}
