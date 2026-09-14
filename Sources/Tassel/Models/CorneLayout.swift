import Foundation

/// One of up to 5 repeating panels (e.g. "Base", "Nav", "Symbols", "Fn", "Mouse").
struct CorneLayout: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var keys: [KeyLayout]

    init(id: UUID = UUID(), name: String, keys: [KeyLayout] = []) {
        self.id = id
        self.name = name
        self.keys = keys
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
struct TasselDocument: Codable, Equatable {
    static let maxLayouts = 5

    var layouts: [CorneLayout]
    var selectedLayoutID: UUID?

    static var empty: TasselDocument {
        TasselDocument(layouts: [.corneV4Base(name: "Base")], selectedLayoutID: nil)
    }

    var canAddLayout: Bool { layouts.count < Self.maxLayouts }
}
