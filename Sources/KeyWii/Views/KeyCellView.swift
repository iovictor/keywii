import SwiftUI

/// Renders one key.
///
/// Rule: if `secondary` is present (text or image, doesn't matter which),
/// primary takes ~70% height and secondary ~30%, always in that stack —
/// so a primary-only-image key and a primary+secondary key size their
/// primary identically, keeping the grid visually uniform.
struct KeyCellView: View {
    let key: KeyLayout

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(key.backgroundColor.color)

                VStack(alignment: .leading, spacing: 0) {
                    contentView(key.primary, fontSize: 10, foregroundColor: key.backgroundColor.contrastingForeground)
                        .frame(
                            height: key.secondary == nil ? nil : geo.size.height * 0.66,
                            // Was `.topLeading` — pinning the (much shorter
                            // than the slot) text to the very top of that
                            // 66% zone read as "primary sitting too high"
                            // whenever a secondary line was present.
                            // Vertically centering it in the zone instead
                            // keeps it near the key's upper area without
                            // gluing it to the top edge.
                            alignment: .leading
                        )
                        .frame(maxHeight: key.secondary == nil ? .infinity : nil, alignment: .leading)

                    if let secondary = key.secondary {
                        contentView(secondary, fontSize: 8, foregroundColor: Self.secondaryColor)
                            .frame(height: geo.size.height * 0.28, alignment: .topLeading)
                            // Primary is now vertically centered in a slot
                            // taller than its own text (see above), so less
                            // gap remains below it than when it was
                            // top-anchored — a smaller nudge keeps
                            // secondary close without overlapping primary.
                            .offset(y: -4)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                // `.clipped()` only crops a view to its OWN frame — without
                // this explicit `.frame(geo.size)` first, the VStack's frame
                // is just its natural (content-driven) size, so clipping it
                // to itself was a no-op. The 70/30 split plus fixed
                // spacing/padding can add up to slightly more than the key's
                // actual height at these small sizes; force the exact size,
                // then clip, so content never visually spills past the
                // rounded-rect background.
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                if let tag = key.tag, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.black.opacity(0.35))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(2)
                }
            }
        }
    }

    /// Fixed accent color for secondary text, independent of the key's own
    /// background — an explicit style choice, unlike primary text (and the
    /// tag), which stay contrast-computed per the locked-in rule.
    private static let secondaryColor = Color(red: 0.55, green: 0.78, blue: 1.0)

    @ViewBuilder
    private func contentView(_ content: KeyContent, fontSize: CGFloat, foregroundColor: Color) -> some View {
        switch content {
        case .text(let str):
            Text(str)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Corrupt/missing image data — show a placeholder rather than blank.
                Image(systemName: "questionmark.square.dashed")
                    .foregroundStyle(foregroundColor.opacity(0.5))
            }
        }
    }
}

#if DEBUG
struct KeyCellView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(alignment: .top, spacing: 8) {
            KeyCellView(key: KeyLayout(
                slotID: "L00",
                primary: .text("Cmd"),
                secondary: .text("⌘"),
                tag: "L1",
                backgroundColor: CodableColor(red: 0.85, green: 0.2, blue: 0.3)
            ))
            .frame(width: CorneV4Geometry.keySize, height: CorneV4Geometry.keySize)

            KeyCellView(key: KeyLayout(
                slotID: "L01",
                primary: .text("Tab"),
                backgroundColor: CodableColor(red: 0.2, green: 0.3, blue: 0.85)
            ))
            .frame(width: CorneV4Geometry.keySize, height: CorneV4Geometry.keySize)

            KeyCellView(key: KeyLayout(
                slotID: "LT2",
                primary: .text("Space"),
                secondary: .text("Lower"),
                tag: "Spc",
                backgroundColor: CodableColor(red: 0.2, green: 0.5, blue: 0.4)
            ))
            .frame(width: CorneV4Geometry.keySize, height: CorneV4Geometry.thumbKeyHeight)
        }
        .padding()
    }
}
#endif
