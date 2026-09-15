import Foundation

/// Absolute placement of a key's top-left corner within its layout's local
/// space, in points. Ported from the real Corne v4 column-stagger + thumb
/// arc geometry (see `CorneV4Geometry`) rather than derived from column/row
/// grid math — the thumb cluster's arc can't be expressed as a grid.
struct KeyPosition: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var rotation: Double

    static func fixed(x: CGFloat, y: CGFloat, rotation: Double = 0) -> KeyPosition {
        KeyPosition(x: x, y: y, rotation: rotation)
    }
}

/// A single key: its primary (required) and secondary (optional) content,
/// a bottom-right text tag, and background color.
///
/// `slotID` ties a key to one of `CorneV4Geometry`'s fixed physical
/// positions (e.g. "L03", "LT2") — a layout is always the full 46-slot
/// board, even where a slot's content is empty. Position itself is *not*
/// stored here: it's derived live from `CorneV4Geometry` by `slotID` so a
/// future geometry tweak applies to every saved document automatically,
/// instead of freezing stale coordinates into `document.json`.
struct KeyLayout: Codable, Identifiable, Equatable {
    let id: UUID
    var slotID: String
    var primary: KeyContent
    var secondary: KeyContent?
    var tag: String?
    var backgroundColor: CodableColor

    init(
        id: UUID = UUID(),
        slotID: String,
        primary: KeyContent,
        secondary: KeyContent? = nil,
        tag: String? = nil,
        backgroundColor: CodableColor = .default
    ) {
        self.id = id
        self.slotID = slotID
        self.primary = primary
        self.secondary = secondary
        self.tag = tag
        self.backgroundColor = backgroundColor
    }

    /// Secondary content is never valid on its own — enforce this in the
    /// editor UI (disable/clear secondary if primary is emptied) as well as
    /// checking it here before persisting.
    var isValid: Bool {
        !(primary.isEmpty && secondary != nil && !(secondary?.isEmpty ?? true))
    }
}
