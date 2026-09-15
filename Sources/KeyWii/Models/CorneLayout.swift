import Foundation

/// One of up to 5 repeating panels (e.g. "Base", "Nav", "Symbols", "Fn", "Mouse").
struct CorneLayout: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var keys: [KeyLayout]
    /// Whether this layout appears as a tab on the read-only shelf. Always
    /// editable in the "Edit Layouts" window regardless of this — it only
    /// controls shelf clutter. Defaults to `true` (custom-decoded so older
    /// saved documents without this field still load instead of failing).
    var isVisibleOnShelf: Bool

    init(id: UUID = UUID(), name: String, keys: [KeyLayout] = [], isVisibleOnShelf: Bool = true) {
        self.id = id
        self.name = name
        self.keys = keys
        self.isVisibleOnShelf = isVisibleOnShelf
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, keys, isVisibleOnShelf
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        keys = try container.decode([KeyLayout].self, forKey: .keys)
        isVisibleOnShelf = try container.decodeIfPresent(Bool.self, forKey: .isVisibleOnShelf) ?? true
    }

    /// A full 46-slot Corne v4 board with every physical position present
    /// but empty (`primary: .text("")`) — the board's shape is fixed
    /// regardless of what content, if any, has been assigned yet.
    static func corneV4Base(name: String) -> CorneLayout {
        let keys = CorneV4Geometry.slots.map { slot in
            KeyLayout(slotID: slot.id, primary: .text(""))
        }
        return CorneLayout(name: name, keys: keys)
    }
}

/// Top-level persisted document: the set of layouts (max 5) shown in the panel.
struct KeyWiiDocument: Codable, Equatable {
    static let maxLayouts = 5

    var layouts: [CorneLayout]
    var selectedLayoutID: UUID?

    /// The document a fresh install (or a corrupt/missing document.json)
    /// starts from — a "Base" layout seeded with the real reference
    /// keymap (see `CorneLayout.corneV4Sample`) rather than an empty
    /// board, so first launch is actually useful to look at.
    static var initial: KeyWiiDocument {
        KeyWiiDocument(layouts: [.corneV4Sample(name: "Base")], selectedLayoutID: nil)
    }

    var canAddLayout: Bool { layouts.count < Self.maxLayouts }
}
