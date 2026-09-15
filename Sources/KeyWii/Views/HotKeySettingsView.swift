import SwiftUI
import AppKit
import HotKey

/// Settings panel — the global shortcut recorder and the shelf's
/// appearance (background/border color). Hosted in a real
/// `EditorWindowController` window (native title bar + close button
/// handle dismissal); only the shortcut *recorder*'s own Esc handling
/// needs special wiring — see `updateEscOverride`.
struct HotKeySettingsView: View {
    @ObservedObject var appearance: ShelfAppearanceStore

    @Environment(\.editorWindowController) private var editorWindowController
    @Environment(\.onHotKeyRecordingStart) private var onHotKeyRecordingStart
    @Environment(\.onHotKeyRecordingEnd) private var onHotKeyRecordingEnd

    @State private var currentCombo = HotKeyPreference.current
    @State private var isRecording = false
    @State private var recordingMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Global Shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: toggleRecording) {
                    Text(isRecording ? "Press a key combo…" : currentCombo.description)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                if isRecording {
                    Text("Include ⌘/⌥/⌃/⇧, or Esc to cancel.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Shelf Appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ColorPicker(
                    "Background",
                    selection: Binding(
                        get: { appearance.background.color },
                        set: { appearance.background = CodableColor(color: $0) }
                    ),
                    supportsOpacity: false
                )

                ColorPicker(
                    "Border",
                    selection: Binding(
                        get: { appearance.border.color },
                        set: { appearance.border = CodableColor(color: $0) }
                    )
                )

                ColorPicker(
                    "Layout Border",
                    selection: Binding(
                        get: { appearance.layoutBorder.color },
                        set: { appearance.layoutBorder = CodableColor(color: $0) }
                    )
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Layout Size")
                    Slider(
                        value: Binding(
                            get: { Double(appearance.cardScale) },
                            set: { appearance.cardScale = CGFloat($0) }
                        ),
                        in: Double(ShelfAppearanceStore.cardScaleRange.lowerBound)...Double(ShelfAppearanceStore.cardScaleRange.upperBound)
                    )
                }

                Button("Reset to Default") {
                    appearance.background = ShelfAppearanceStore.defaultBackground
                    appearance.border = ShelfAppearanceStore.defaultBorder
                    appearance.cardScale = ShelfAppearanceStore.defaultCardScale
                    appearance.layoutBorder = ShelfAppearanceStore.defaultLayoutBorder
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 220)
        .onAppear { updateEscOverride() }
        .onChange(of: isRecording) { _ in updateEscOverride() }
        .onDisappear {
            if isRecording { cancelRecording() }
            editorWindowController?.escOverride = nil
        }
    }

    /// While recording, Esc should cancel just the recording, not close the
    /// whole settings window (`EditorWindowController`'s own Esc monitor
    /// already closes the window by default whenever no override claims
    /// the event, so nothing else is needed once recording ends).
    private func updateEscOverride() {
        editorWindowController?.escOverride = isRecording ? {
            cancelRecording()
            return true
        } : nil
    }

    private func toggleRecording() {
        isRecording ? cancelRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        // The old shortcut is still live until a new one is confirmed —
        // pause it so pressing that same combo while recording doesn't
        // fire its Carbon-level handler (which would toggle the panel
        // closed) before this monitor sees the keystroke.
        onHotKeyRecordingStart?()

        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc cancels without changing anything
                cancelRecording()
                return nil
            }

            // Require at least one modifier so we never bind a bare letter
            // key as a system-wide shortcut.
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !modifiers.isEmpty, let key = Key(carbonKeyCode: UInt32(event.keyCode)) else {
                return nil
            }

            let combo = KeyCombo(key: key, modifiers: modifiers)
            currentCombo = combo
            isRecording = false
            removeRecordingMonitor()
            onHotKeyRecordingEnd?(combo)
            return nil
        }
    }

    private func cancelRecording() {
        isRecording = false
        removeRecordingMonitor()
        onHotKeyRecordingEnd?(nil)
    }

    private func removeRecordingMonitor() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
        }
        recordingMonitor = nil
    }
}
