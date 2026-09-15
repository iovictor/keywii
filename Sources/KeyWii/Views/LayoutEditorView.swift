import SwiftUI

/// Root content of the "Edit Layouts" window — the one place all editing
/// happens (see AGENTS.md's "Editor architecture" section for why this is
/// separate from the hotkey shelf). Layout tabs (with add/rename/delete)
/// on top, the keyboard grid below that (click a key to select it), and
/// the selected key's fields docked along the bottom.
struct LayoutEditorView: View {
    @ObservedObject var store: DocumentStore
    @State private var selectedSlotID: String?
    @State private var renamingLayoutID: UUID?
    @State private var renameDraft: String = ""

    private var selectedLayout: CorneLayout? {
        store.document.layouts.first { $0.id == store.document.selectedLayoutID }
            ?? store.document.layouts.first
    }

    var body: some View {
        VStack(spacing: 16) {
            layoutSwitcher

            if let layout = selectedLayout {
                KeyboardGridView(
                    layout: layout,
                    selectedSlotID: selectedSlotID,
                    onSelectKey: { slotID in
                        commitRename()
                        selectedSlotID = slotID
                    }
                )
            } else {
                Text("No layouts yet")
                    .foregroundStyle(.secondary)
            }

            Divider()

            keyEditorSection
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 560)
    }

    /// Reserves the same height whether or not a key is selected —
    /// `EditorWindowController.show()` sizes the window exactly once, from
    /// `NSHostingView.fittingSize` at the moment it opens (before any key
    /// is selected, so this section would otherwise report just the short
    /// placeholder's height). If a later selection made this section
    /// report a *taller* natural size, the window wouldn't grow to match
    /// — SwiftUI would just render the real, taller `KeyEditorView`
    /// squeezed into the original fixed window bounds, clipping or
    /// overlapping its bottom fields (confirmed as the cause of a
    /// "wonky"-to-click Secondary checkbox and a seemingly-inert image
    /// picker button — both were landing in that clipped-off space).
    private static let keyEditorSectionHeight: CGFloat = 320

    @ViewBuilder
    private var keyEditorSection: some View {
        Group {
            if let layout = selectedLayout,
               let slotID = selectedSlotID,
               let binding = store.keyBinding(layoutID: layout.id, slotID: slotID) {
                KeyEditorView(key: binding)
                    .frame(maxWidth: 420)
            } else {
                Text("Click a key above to edit it")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.keyEditorSectionHeight, alignment: .top)
    }

    private var layoutSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Array(store.document.layouts.enumerated()), id: \.element.id) { index, layout in
                LayoutTab(
                    layout: layout,
                    isSelected: layout.id == selectedLayout?.id,
                    isRenaming: renamingLayoutID == layout.id,
                    canDelete: store.document.layouts.count > 1,
                    canMoveLeft: index > 0,
                    canMoveRight: index < store.document.layouts.count - 1,
                    renameDraft: $renameDraft,
                    onSelect: { selectLayout(layout.id) },
                    onBeginRename: { beginRename(layout) },
                    onCommitRename: commitRename,
                    onDelete: { deleteLayout(layout.id) },
                    onToggleShelfVisibility: { toggleShelfVisibility(layout.id) },
                    onMoveLeft: { moveLayout(at: index, by: -1) },
                    onMoveRight: { moveLayout(at: index, by: 1) }
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

    private func toggleShelfVisibility(_ id: UUID) {
        guard let index = store.document.layouts.firstIndex(where: { $0.id == id }) else { return }
        store.document.layouts[index].isVisibleOnShelf.toggle()
        store.save()
    }

    /// Swaps a layout with its neighbor `offset` slots away (±1). Also
    /// controls the order layouts appear in on the shelf's grid (see
    /// `PanelContentView.rows`), which reads `store.document.layouts` in
    /// array order — this is the only way to reorder them there.
    private func moveLayout(at index: Int, by offset: Int) {
        commitRename()
        let target = index + offset
        guard store.document.layouts.indices.contains(index),
              store.document.layouts.indices.contains(target)
        else { return }
        store.document.layouts.swapAt(index, target)
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
    /// to call unconditionally — every other action in this view calls
    /// this first so a pending rename is never silently lost when the user
    /// clicks elsewhere (clicking a non-text-input view doesn't reliably
    /// move AppKit focus off a `TextField`, so focus-loss can't be relied
    /// on to commit it).
    private func commitRename() {
        guard let id = renamingLayoutID else { return }
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let index = store.document.layouts.firstIndex(where: { $0.id == id }) {
            store.document.layouts[index].name = trimmed
            store.save()
        }
        renamingLayoutID = nil
    }
}

/// One capsule in the layout tab strip: tap to select; the active tab also
/// shows a pencil (inline rename) and, when more than one layout exists, a
/// delete button. The eye icon toggles whether this layout appears as a
/// tab on the read-only shelf — always editable here regardless.
private struct LayoutTab: View {
    let layout: CorneLayout
    let isSelected: Bool
    let isRenaming: Bool
    let canDelete: Bool
    let canMoveLeft: Bool
    let canMoveRight: Bool
    @Binding var renameDraft: String
    let onSelect: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void
    let onToggleShelfVisibility: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if isSelected && canMoveLeft {
                Button(action: onMoveLeft) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Move earlier")
            }

            Button(action: onToggleShelfVisibility) {
                Image(systemName: layout.isVisibleOnShelf ? "eye.fill" : "eye.slash")
                    .font(.system(size: 9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(layout.isVisibleOnShelf ? "Shown on shelf — click to hide" : "Hidden from shelf — click to show")

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

            if isSelected && canMoveRight {
                Button(action: onMoveRight) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Move later")
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
