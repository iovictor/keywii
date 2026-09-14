import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Inline editor for one key's content, tag, and background color.
///
/// This is an in-panel overlay, not a `.sheet`/separate window: a real
/// child window becoming key would make `OverlayPanel` resign key and
/// auto-hide out from under the editor (see `OverlayPanel.resignKey`).
struct KeyEditorView: View {
    @Binding var key: KeyLayout
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(key.slotID)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ContentFieldEditor(title: "Primary", content: primaryBinding)

            SecondaryFieldEditor(secondary: $key.secondary, primaryIsEmpty: key.primary.isEmpty)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tag").font(.caption).foregroundStyle(.secondary)
                TextField("Tag", text: tagBinding)
                    .textFieldStyle(.roundedBorder)
            }

            ColorPicker("Background", selection: colorBinding, supportsOpacity: false)
        }
        .padding(14)
        .frame(width: 260)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 16)
    }

    /// Setting primary empty clears secondary too — secondary is never
    /// valid without primary (see `KeyLayout.isValid`).
    private var primaryBinding: Binding<KeyContent> {
        Binding(
            get: { key.primary },
            set: { newValue in
                key.primary = newValue
                if newValue.isEmpty { key.secondary = nil }
            }
        )
    }

    private var tagBinding: Binding<String> {
        Binding(get: { key.tag ?? "" }, set: { key.tag = $0.isEmpty ? nil : $0 })
    }

    private var colorBinding: Binding<Color> {
        Binding(get: { key.backgroundColor.color }, set: { key.backgroundColor = CodableColor(color: $0) })
    }
}

/// Text/Image toggle plus the matching text field or image picker for one
/// `KeyContent` value.
private struct ContentFieldEditor: View {
    let title: String
    @Binding var content: KeyContent

    private enum Kind: String, Hashable {
        case text, image
    }

    private var kind: Kind {
        switch content {
        case .text: return .text
        case .image: return .image
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { kind },
                set: { newKind in
                    switch newKind {
                    case .text: content = .text("")
                    case .image: content = .image(Data())
                    }
                }
            )) {
                Text("Text").tag(Kind.text)
                Text("Image").tag(Kind.image)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch content {
            case .text(let str):
                TextField(title, text: Binding(get: { str }, set: { content = .text($0) }))
                    .textFieldStyle(.roundedBorder)
            case .image(let data):
                ImagePickerRow(data: data) { content = .image($0) }
            }
        }
    }
}

/// Toggle to enable/disable the optional secondary field, plus its content
/// editor when enabled. Disabled entirely while primary is empty, since
/// secondary is never valid without primary.
private struct SecondaryFieldEditor: View {
    @Binding var secondary: KeyContent?
    let primaryIsEmpty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { secondary != nil },
                set: { secondary = $0 ? .text("") : nil }
            )) {
                Text("Secondary").font(.caption).foregroundStyle(.secondary)
            }
            .disabled(primaryIsEmpty)

            if let value = secondary {
                ContentFieldEditor(title: "Secondary", content: Binding(get: { value }, set: { secondary = $0 }))
            }
        }
    }
}

/// Thumbnail + "Choose…" button for picking an image file from disk.
private struct ImagePickerRow: View {
    let data: Data
    let onPick: (Data) -> Void

    @Environment(\.overlayPanel) private var overlayPanel

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)

            Button("Choose…", action: pickImage)
            Spacer()
        }
    }

    private func pickImage() {
        // The open panel becomes its own key window; suppress our panel's
        // resignKey auto-hide for the duration so it doesn't slide away
        // mid-pick.
        overlayPanel?.suppressAutoHide = true
        defer { overlayPanel?.suppressAutoHide = false }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            onPick(data)
        }
    }
}
