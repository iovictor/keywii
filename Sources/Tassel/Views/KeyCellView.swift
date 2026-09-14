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

                VStack(spacing: 2) {
                    contentView(key.primary)
                        .frame(height: key.secondary == nil ? nil : geo.size.height * 0.66)
                        .frame(maxHeight: key.secondary == nil ? .infinity : nil)

                    if let secondary = key.secondary {
                        contentView(secondary)
                            .frame(height: geo.size.height * 0.28)
                    }
                }
                .padding(4)

                if let tag = key.tag, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(key.backgroundColor.contrastingForeground.opacity(0.75))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(3)
                }
            }
        }
    }

    @ViewBuilder
    private func contentView(_ content: KeyContent) -> some View {
        switch content {
        case .text(let str):
            Text(str)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(key.backgroundColor.contrastingForeground)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Corrupt/missing image data — show a placeholder rather than blank.
                Image(systemName: "questionmark.square.dashed")
                    .foregroundStyle(key.backgroundColor.contrastingForeground.opacity(0.5))
            }
        }
    }
}

#if DEBUG
struct KeyCellView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            KeyCellView(key: KeyLayout(
                slotID: "L00",
                primary: .text("Cmd"),
                secondary: .text("⌘"),
                tag: "L1",
                backgroundColor: CodableColor(red: 0.85, green: 0.2, blue: 0.3)
            ))
            KeyCellView(key: KeyLayout(
                slotID: "L01",
                primary: .text("Tab"),
                backgroundColor: CodableColor(red: 0.2, green: 0.3, blue: 0.85)
            ))
        }
        .frame(width: 200, height: 64)
        .padding()
    }
}
#endif
