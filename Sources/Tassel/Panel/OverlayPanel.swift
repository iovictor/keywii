import AppKit
import SwiftUI

/// A borderless, non-activating floating panel that slides up from the
/// bottom third of the screen when shown, and slides back down when it
/// loses key status or Esc is pressed.
final class OverlayPanel: NSPanel {
    private var escMonitor: Any?
    private var isAnimating = false

    /// Set while a native modal (e.g. the image-file picker from the key
    /// editor) is on screen, so `resignKey` doesn't auto-hide the panel out
    /// from under it. See `KeyEditorEnvironment`.
    var suppressAutoHide = false

    convenience init(store: DocumentStore) {
        let hostingView = NSHostingView(rootView: AnyView(PanelContentView(store: store)))
        hostingView.frame = CGRect(x: 0, y: 0, width: 720, height: 320)

        self.init(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentView = hostingView
        configureAppearance()

        // Re-set now that `self` exists, so the editor can reach back to
        // this panel's `suppressAutoHide`.
        hostingView.rootView = AnyView(PanelContentView(store: store).environment(\.overlayPanel, self))
    }

    private func configureAppearance() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false
        // Nonactivating panels don't take app focus from the frontmost app,
        // but can still become key so we can detect resignKey to auto-hide.
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Positioning

    /// Frame anchored at the bottom third of the given screen, hidden
    /// (below the screen edge) and shown (settled) variants.
    private func hiddenFrame(on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let width: CGFloat = min(760, visible.width - 80)
        let height: CGFloat = min(360, visible.height / 3)
        let x = visible.midX - width / 2
        // Parked just below the visible area so the slide-up is seamless.
        let y = visible.minY - height - 20
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func shownFrame(on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let width: CGFloat = min(760, visible.width - 80)
        let height: CGFloat = min(360, visible.height / 3)
        let x = visible.midX - width / 2
        let y = visible.minY + 24
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Show / hide

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard !isVisible, let screen = NSScreen.main else { return }
        setFrame(hiddenFrame(on: screen), display: false)
        orderFrontRegardless()
        makeKey()
        installEscMonitor()

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(shownFrame(on: screen), display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
        })
    }

    func hide() {
        guard isVisible, let screen = NSScreen.main, !isAnimating else { return }
        removeEscMonitor()

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrame(hiddenFrame(on: screen), display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.orderOut(nil)
        })
    }

    // MARK: - Auto-hide triggers

    override func resignKey() {
        super.resignKey()
        if !suppressAutoHide {
            hide()
        }
    }

    private func installEscMonitor() {
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                self.hide()
                return nil // swallow the key so it doesn't propagate
            }
            return event
        }
    }

    private func removeEscMonitor() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }
}

private struct OverlayPanelEnvironmentKey: EnvironmentKey {
    static let defaultValue: OverlayPanel? = nil
}

extension EnvironmentValues {
    /// The panel hosting this view, so a native modal (e.g. an image file
    /// picker) can suppress the panel's resignKey-triggered auto-hide while
    /// it's on screen.
    var overlayPanel: OverlayPanel? {
        get { self[OverlayPanelEnvironmentKey.self] }
        set { self[OverlayPanelEnvironmentKey.self] = newValue }
    }
}
