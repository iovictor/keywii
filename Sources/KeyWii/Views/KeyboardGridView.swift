import SwiftUI

/// Renders one layout's full 46-key board using the real Corne v4
/// stagger/thumb-arc geometry from `CorneV4Geometry`. Shared by
/// `PanelContentView` (pure display, no interaction) and
/// `LayoutEditorView` (clickable, with a selection highlight) — pass
/// `onSelectKey` to make keys tappable, or leave it `nil` for a plain,
/// non-interactive board.
struct KeyboardGridView: View {
    let layout: CorneLayout
    var selectedSlotID: String? = nil
    var onSelectKey: ((String) -> Void)? = nil

    private var placedKeys: [(key: KeyLayout, slot: CorneV4Geometry.Slot)] {
        let slotsByID = Dictionary(uniqueKeysWithValues: CorneV4Geometry.slots.map { ($0.id, $0) })
        return layout.keys.compactMap { key in slotsByID[key.slotID].map { (key, $0) } }
    }

    var body: some View {
        let boardSize = CorneV4Geometry.boardSize

        return ZStack(alignment: .topLeading) {
            // Anchors the ZStack's own layout size to the full board *before*
            // any positioned children are considered — without this, the
            // ZStack's natural size collapses to its largest single child,
            // and every key's tap gesture ends up hit-testing against that
            // shared, tiny reference frame instead of its own true position.
            Color.clear
                .frame(width: boardSize.width, height: boardSize.height)

            ForEach(placedKeys, id: \.key.id) { entry in
                let height = entry.slot.isThumb ? CorneV4Geometry.thumbKeyHeight : CorneV4Geometry.keySize

                keyView(for: entry.key)
                    .overlay {
                        if selectedSlotID == entry.key.slotID {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                    .frame(width: CorneV4Geometry.keySize, height: height)
                    .rotationEffect(.degrees(entry.slot.position.rotation))
                    .position(
                        x: entry.slot.position.x + CorneV4Geometry.keySize / 2,
                        y: entry.slot.position.y + height / 2
                    )
            }
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func keyView(for key: KeyLayout) -> some View {
        if let onSelectKey {
            Button { onSelectKey(key.slotID) } label: { KeyCellView(key: key) }
                .buttonStyle(.plain)
        } else {
            KeyCellView(key: key)
        }
    }
}
