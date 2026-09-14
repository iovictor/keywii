import SwiftUI

/// Root view shown inside the sliding panel: a small tab strip to switch
/// between the up-to-5 Corne layouts, and a grid of that layout's keys.
///
/// Key placement uses the real Corne v4 stagger/thumb-arc geometry from
/// `CorneV4Geometry`, ported from corne-v4-visualizer.
struct PanelContentView: View {
    @ObservedObject var store: DocumentStore
    @State private var selectedSlotID: String?
    @State private var renamingLayoutID: UUID?
    @State private var renameDraft: String = ""

    private var selectedLayout: CorneLayout? {
        store.document.layouts.first { $0.id == store.document.selectedLayoutID }
            ?? store.document.layouts.first
    }

    var body: some View {
        VStack(spacing: 12) {
            layoutSwitcher

            if let layout = selectedLayout {
                keyGrid(for: layout)
            } else {
                Text("No layouts yet")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay { editorOverlay }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var editorOverlay: some View {
        if let layout = selectedLayout,
           let slotID = selectedSlotID,
           let binding = keyBinding(layoutID: layout.id, slotID: slotID) {
            ZStack {
                Color.black.opacity(0.25)
                    .onTapGesture { selectedSlotID = nil }
                KeyEditorView(key: binding) { selectedSlotID = nil }
            }
        }
    }

    /// Live binding into `store.document` for one key, identified by its
    /// stable `slotID` (not array index, which can shift). Every write
    /// through this binding persists immediately, per CLAUDE.md's
    /// "call save() after each committed edit" convention.
    private func keyBinding(layoutID: UUID, slotID: String) -> Binding<KeyLayout>? {
        guard let layoutIndex = store.document.layouts.firstIndex(where: { $0.id == layoutID }),
              let keyIndex = store.document.layouts[layoutIndex].keys.firstIndex(where: { $0.slotID == slotID })
        else { return nil }

        return Binding(
            get: { store.document.layouts[layoutIndex].keys[keyIndex] },
            set: { newValue in
                store.document.layouts[layoutIndex].keys[keyIndex] = newValue
                store.save()
            }
        )
    }

    private var layoutSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(store.document.layouts) { layout in
                LayoutTab(
                    layout: layout,
                    isSelected: layout.id == selectedLayout?.id,
                    isRenaming: renamingLayoutID == layout.id,
                    canDelete: store.document.layouts.count > 1,
                    renameDraft: $renameDraft,
                    onSelect: { selectLayout(layout.id) },
                    onBeginRename: { beginRename(layout) },
                    onCommitRename: commitRename,
                    onDelete: { deleteLayout(layout.id) }
                )
            }

            if store.document.canAddLayout {
                Button(action: addLayout) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private func selectLayout(_ id: UUID) {
        commitRename()
        guard store.document.selectedLayoutID != id else { return }
        store.document.selectedLayoutID = id
        selectedSlotID = nil
        store.save()
    }

    private func addLayout() {
        commitRename()
        guard store.document.canAddLayout else { return }
        let newLayout = CorneLayout.corneV4Base(name: "Layer \(store.document.layouts.count + 1)")
        store.document.layouts.append(newLayout)
        store.document.selectedLayoutID = newLayout.id
        selectedSlotID = nil
        store.save()
    }

    private func deleteLayout(_ id: UUID) {
        commitRename()
        guard store.document.layouts.count > 1,
              let index = store.document.layouts.firstIndex(where: { $0.id == id })
        else { return }

        let wasSelected = store.document.selectedLayoutID == id
        store.document.layouts.remove(at: index)
        if wasSelected {
            store.document.selectedLayoutID = store.document.layouts.first?.id
        }
        selectedSlotID = nil
        store.save()
    }

    /// Enters inline rename for a tab. Commits any other tab's pending
    /// rename first — only one can be active at a time.
    private func beginRename(_ layout: CorneLayout) {
        commitRename()
        renameDraft = layout.name
        renamingLayoutID = layout.id
    }

    /// Saves the current rename draft (if any) and exits rename mode. Safe
    /// to call unconditionally — every other panel action calls this first
    /// so a pending rename is never silently lost when the user clicks
    /// elsewhere (clicking a non-text-input view doesn't reliably move
    /// AppKit focus off a `TextField`, so focus-loss can't be relied on).
    private func commitRename() {
        guard let id = renamingLayoutID else { return }
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let index = store.document.layouts.firstIndex(where: { $0.id == id }) {
            store.document.layouts[index].name = trimmed
            store.save()
        }
        renamingLayoutID = nil
    }

    private func keyGrid(for layout: CorneLayout) -> some View {
        let slotsByID = Dictionary(uniqueKeysWithValues: CorneV4Geometry.slots.map { ($0.id, $0) })
        let boardSize = CorneV4Geometry.boardSize

        return ZStack(alignment: .topLeading) {
            ForEach(layout.keys) { key in
                if let slot = slotsByID[key.slotID] {
                    let height = slot.isThumb ? CorneV4Geometry.thumbKeyHeight : CorneV4Geometry.keySize

                    KeyCellView(key: key)
                        .frame(width: CorneV4Geometry.keySize, height: height)
                        .rotationEffect(.degrees(slot.position.rotation))
                        .offset(x: slot.position.x, y: slot.position.y)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            commitRename()
                            selectedSlotID = key.slotID
                        }
                }
            }
        }
        .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
    }
}

/// One capsule in the layout tab strip: tap to select; the active tab also
/// shows a pencil (inline rename) and, when more than one layout exists, a
/// delete button.
///
/// Rename state (whether this tab is being renamed, and the draft text) is
/// owned by `PanelContentView`, not this view — a plain click elsewhere in
/// the panel doesn't reliably move AppKit's first responder off a
/// `TextField`, so "click away to commit" can't rely on focus loss and is
/// instead handled explicitly by every other panel action calling
/// `PanelContentView.commitRename()` first.
private struct LayoutTab: View {
    let layout: CorneLayout
    let isSelected: Bool
    let isRenaming: Bool
    let canDelete: Bool
    @Binding var renameDraft: String
    let onSelect: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isRenaming {
                TextField("Name", text: $renameDraft, onCommit: onCommitRename)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 80)
            } else {
                Text(layout.name)
                    .font(.system(size: 12, weight: .medium))
            }

            if isSelected && !isRenaming {
                Button(action: onBeginRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(Capsule())
        .onTapGesture {
            if !isRenaming { onSelect() }
        }
    }
}
