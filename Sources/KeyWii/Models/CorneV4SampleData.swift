import Foundation

extension CorneLayout {
    /// A "Base" layout seeded with the reference keymap from
    /// `corne-v4-visualizer/data.json`'s "capslock" layer — real content
    /// to start from instead of an empty board. Ported by hand (label,
    /// secondary label, tag) per physical slot; background colors are
    /// left at the default since the source project's category-color
    /// system doesn't map onto this app's simpler per-key custom color.
    ///
    /// Slot IDs here use *this* project's `"L{column}{row}"` convention
    /// (see `CorneV4Geometry`) — note the source data.json's IDs are the
    /// opposite, `"L{row}{column}"` (e.g. its "L03" is row 0, column 3).
    /// Getting this backwards was a real bug: copying the source IDs
    /// verbatim either stacked several keys' content into one physical
    /// column (when both digits were in-range for the wrong axis) or
    /// silently dropped it entirely (when the swapped row/column values
    /// were out of range for any slot, so `KeyboardGridView` filtered it
    /// out) — which looked like "half the keyboard is missing."
    static func corneV4Sample(name: String) -> CorneLayout {
        // (slotID, primary, secondary, tag)
        let entries: [(String, String, String?, String?)] = [
            ("L00", "⎋ Esc", nil, "Esc"),
            ("L10", "Close App", "⌘Q", "Q"),
            ("L20", "Close Tab", "⌘W", "W"),
            ("L30", "Chrome", "Finder", "E"),
            ("L40", "iTerm2", "Term", "R"),
            ("L50", "Code", "Agy IDE", "T"),
            ("L60", "CRKBD", "Cheat", nil),
            ("L01", "Hyper", "⇥ Tab", "✱"),
            ("L11", "Moom", "Moom", "A"),
            ("L21", "Switch Tab", "Next Tab", "S"),
            ("L31", "Zed", "Sublime", "D"),
            ("L41", "Alfred", "Spotlight", "F"),
            ("L51", "Claude", "Antigravity", "G"),
            ("L61", "Clip Board", "History", nil),
            ("L02", "⇧ Shift", nil, "Shift"),
            ("L12", "Ctrl-Z", "Undo*", "Z"),
            ("L22", "Ctrl-R", "Ctrl-D", "X"),
            ("L32", "Ctrl-C", "Define", "C"),
            ("L42", "Ctrl-V", "Mail", "V"),
            ("L52", "Space-B", "Ctrl-B", "B"),
            ("LT0", "⌘ Cmd", "Hyper Sub", "cmd"),
            ("LT1", "Lower", "Numbers", "L1"),
            ("LT2", "␣ Spc", "Space", "Spc"),
            ("R00", "⌦ Del", "Delete", "Del"),
            ("R10", "PgDn", "Next Page", "P"),
            ("R20", "End", "Line End", "O"),
            ("R30", "Home", "Line Head", "I"),
            ("R40", "PgUp", "Prev Page", "U"),
            ("R50", "Obsidian", "Notes", "Y"),
            ("R60", "⌥ Opt", nil, nil),
            ("R01", "'", nil, nil),
            ("R11", ";", nil, nil),
            ("R21", "→ Sel Word", nil, "L"),
            ("R31", "Sel Line ↑", nil, "K"),
            ("R41", "Sel Line ↓", nil, "J"),
            ("R51", "← Sel Word", nil, "H"),
            ("R61", "⌃ Ctrl", nil, nil),
            ("R02", "⇧ Shift", nil, "Shift"),
            ("R12", "/", nil, nil),
            ("R22", "Del Word >", nil, "."),
            ("R32", "Del Char >", nil, ","),
            ("R42", "< Del Char", nil, "M"),
            ("R52", "< Del Word", nil, "N"),
            ("RT0", "⏎ Enter", "Return", "Ent"),
            ("RT1", "Raise", "Arrows", "L2"),
            ("RT2", "⌫ Bksp", nil, "Bksp"),
        ]

        let keys = entries.map { slotID, primary, secondary, tag in
            KeyLayout(
                slotID: slotID,
                primary: .text(primary),
                secondary: secondary.map { .text($0) },
                tag: tag
            )
        }
        return CorneLayout(name: name, keys: keys)
    }
}
