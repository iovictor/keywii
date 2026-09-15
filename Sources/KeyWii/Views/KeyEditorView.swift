import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Editor for one key's content, tag, and background color. Docked along
/// the bottom of `LayoutEditorView` — a real, normally-activating window,
/// which is why `ColorPicker` and the image file picker just work here
/// with zero special-casing (see AGENTS.md's "Editor architecture").
struct KeyEditorView: View {
    @Binding var key: KeyLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ContentFieldEditor(title: "Primary", content: primaryBinding)

            SecondaryFieldEditor(secondary: $key.secondary, primaryIsEmpty: key.primary.isEmpty)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tag").font(.caption).foregroundStyle(.secondary)
                TextField("Tag", text: tagBinding)
                    .textFieldStyle(.roundedBorder)
            }

            ColorPicker("Background", selection: colorBinding, supportsOpacity: false)
        }
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

            // A `Picker` with `.pickerStyle(.segmented)` driven by a custom
            // derived `Binding` (rather than a plain `@State`) was
            // confirmed unreliable here — clicking "Image" fired the
            // binding's setter repeatedly but the selection kept snapping
            // back to "Text" without ever visibly switching. Plain
            // buttons sidestep whatever internal reconciliation the
            // segmented Picker style was doing.
            HStack(spacing: 0) {
                kindButton(.text, label: "Text")
                kindButton(.image, label: "Image")
            }
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            switch content {
            case .text(let str):
                TextField(title, text: Binding(get: { str }, set: { content = .text($0) }))
                    .textFieldStyle(.roundedBorder)
            case .image(let data):
                ImagePickerRow(data: data) { content = .image($0) }
            }
        }
    }

    @ViewBuilder
    private func kindButton(_ target: Kind, label: String) -> some View {
        let isSelected = kind == target
        Button {
            switch target {
            case .text: content = .text("")
            case .image: content = .image(Data())
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundStyle(isSelected ? .white : .primary)
                // `.buttonStyle(.plain)` otherwise leaves only the text
                // glyphs themselves clickable, not the surrounding
                // padding/background — confirmed as exactly why this
                // looked broken ("have to click the text itself").
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

/// Thumbnail + "Choose Image…"/"From App…" buttons for picking a key's
/// image content, either an arbitrary file from disk or an installed
/// app's own icon.
private struct ImagePickerRow: View {
    let data: Data
    let onPick: (Data) -> Void

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

            Button("Choose Image…", action: pickImage)
            Button("From App…", action: pickAppIcon)
            Spacer()
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            onPick(data)
        }
    }

    /// Lets the user browse to any `.app` bundle and uses `NSWorkspace`'s
    /// own icon lookup for it — the same icon macOS shows in Finder/Dock
    /// for that app, at whatever resolution it registered (so a Retina
    /// icon comes back sharp). Re-rendered into a fixed-size PNG since
    /// `KeyContent.image` stores flat `Data`, not an `NSImage`/icon
    /// reference — the source app being moved, renamed, or removed later
    /// doesn't affect an icon already captured this way.
    private func pickAppIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Use Icon"
        panel.message = "Choose an app to use its icon"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        if let data = Self.pngData(from: icon, side: 128) {
            onPick(data)
        }
    }

    private static func pngData(from image: NSImage, side: CGFloat) -> Data? {
        let size = NSSize(width: side, height: side)
        let resized = NSImage(size: size)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
