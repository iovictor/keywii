import Foundation

/// The fixed physical shape of a Corne v4 keyboard half: which key slots
/// exist and where they sit, ported from the column-stagger and thumb-arc
/// geometry in `corne-v4-visualizer/public/styles.css` (the reference
/// project named in CLAUDE.md), scaled down from its 100pt keycaps to this
/// panel's smaller ones.
///
/// This shape is independent of any layout's data — a `CorneLayout` always
/// has one `KeyLayout` per slot here (see `CorneLayout.corneV4Base`), so the
/// board renders in full even where a slot's content is empty.
///
/// **Slot ID convention: `"L{column}{row}"` / `"R{column}{row}"`** — column
/// digit first, then row (thumbs are just `"LT{index}"`/`"RT{index}"`, no
/// ambiguity there). This is the *opposite* digit order from the source
/// `corne-v4-visualizer/data.json`, which uses `"{row}{column}"` — e.g. its
/// "L03" is row 0, column 3, while here that same physical key is "L30".
/// Copying source IDs verbatim without swapping the digits was a real bug
/// (see `CorneV4SampleData.swift`'s doc comment for exactly what it looked
/// like) — double check this when porting any more reference data in.
enum CorneV4Geometry {
    static let keySize: CGFloat = 52
    /// Height of the innermost thumb key only — source CSS's `.key.thumb`
    /// overrides just `height` (160px vs the normal 100px); width is
    /// unchanged (`--key-size`) for every key, thumb or not.
    static let thumbKeyHeight: CGFloat = keySize * 1.6
    static let gap: CGFloat = 6
    /// Gap between the left and right halves.
    static let halfGap: CGFloat = 28

    /// `translateY` per column in the source CSS (`.left-half .col-N`),
    /// outer pinky (0) to inner index (6). Mirrored for the right half.
    private static let columnStaggerPx: [CGFloat] = [30, 30, -4, -20, -4, 10, 10]

    /// Column 6 ("inner-keys") only has a top and middle row on the real
    /// board; every other column has all 3 rows.
    private static let rowsPerColumn: [Int] = [3, 3, 3, 3, 3, 3, 2]

    /// (keySize + gap) here, over (100 + 8) in the source CSS's key pitch.
    private static let scale: CGFloat = (keySize + gap) / 108

    /// Thumb key arc, left hand: `right`/`top` offsets from the thumb
    /// cluster's own right edge, and the rotation that arcs each key
    /// toward the board's center. Ported from `.left-half .thumb-N`.
    private static let thumbOffsets: [(right: CGFloat, top: CGFloat, rotation: Double)] = [
        (right: 272, top: 20, rotation: 0),
        (right: 143, top: 27, rotation: 9),
        (right: -4, top: 4, rotation: 20),
    ]

    struct Slot {
        let id: String
        let position: KeyPosition
        let isThumb: Bool
    }

    /// All 46 physical slots (23 per half: 20 matrix keys + 3 thumb keys),
    /// keyed by a stable ID like "L03" or "RT2".
    static let slots: [Slot] = makeSlots()

    /// Bounding size of the full board, for sizing the panel's grid area.
    static let boardSize: CGSize = {
        let maxX = slots.map { $0.position.x + keySize }.max() ?? 0
        let maxY = slots.map { $0.position.y + ($0.isThumb ? thumbKeyHeight : keySize) }.max() ?? 0
        return CGSize(width: maxX, height: maxY)
    }()

    private static func makeSlots() -> [Slot] {
        var slots: [Slot] = []

        let columnCount = columnStaggerPx.count
        let matrixWidth = CGFloat(columnCount) * (keySize + gap) - gap
        let matrixHeight = 3 * (keySize + gap) - gap
        let scaledStagger = columnStaggerPx.map { $0 * scale }
        // Shift everything down so the highest-staggered key sits at y = 0.
        let topPadding = -(scaledStagger.min() ?? 0)

        func leftX(_ column: Int) -> CGFloat {
            CGFloat(column) * (keySize + gap)
        }
        func rightX(_ column: Int) -> CGFloat {
            // Mirrored: the right half's column 0 sits at its outer (right) edge.
            matrixWidth + halfGap + CGFloat(columnCount - 1 - column) * (keySize + gap)
        }

        for column in 0..<columnCount {
            let rows = rowsPerColumn[column]
            let staggerY = scaledStagger[column] + topPadding
            // Center the 2-row inner column within the 3-row matrix height.
            let rowInset = rows == 2 ? (keySize + gap) / 2 : 0

            for row in 0..<rows {
                let y = staggerY + rowInset + CGFloat(row) * (keySize + gap)
                slots.append(Slot(id: "L\(column)\(row)", position: .fixed(x: leftX(column), y: y), isThumb: false))
                slots.append(Slot(id: "R\(column)\(row)", position: .fixed(x: rightX(column), y: y), isThumb: false))
            }
        }

        let thumbClusterTop = matrixHeight + topPadding + 14 * scale
        let rightHalfOriginX = matrixWidth + halfGap
        // Only the innermost thumb key per half (last in the arc, closest to
        // the center gap) is the tall "thumb-3" key in the source CSS — the
        // other two are normal key size.
        let tallIndex = thumbOffsets.count - 1
        // The tall keys' rotation swings their corners out horizontally well
        // past their unrotated bounding box, making them read as touching at
        // the source's 1:1 offsets once scaled down — nudge them apart.
        let innermostThumbExtraGap: CGFloat = 10

        for (index, offset) in thumbOffsets.enumerated() {
            let isTall = index == tallIndex
            let extraPush = isTall ? innermostThumbExtraGap : 0
            let scaledRight = offset.right * scale
            let scaledTop = offset.top * scale
            let y = thumbClusterTop + scaledTop

            slots.append(Slot(
                id: "LT\(index)",
                position: .fixed(x: matrixWidth - keySize - scaledRight - extraPush, y: y, rotation: offset.rotation),
                isThumb: isTall
            ))
            slots.append(Slot(
                id: "RT\(index)",
                position: .fixed(x: rightHalfOriginX + scaledRight + extraPush, y: y, rotation: -offset.rotation),
                isThumb: isTall
            ))
        }

        return slots
    }
}
