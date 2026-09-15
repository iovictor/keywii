import AppKit
import SwiftUI

/// A borderless, non-activating floating panel that slides up from the
/// bottom third of the screen when shown, and slides back down when it
/// loses key status or Esc is pressed.
///
/// Pure display — no editing lives here (see AGENTS.md's "Editor
/// architecture" section). Because this panel has no reason to ever host
/// a native modal (`NSColorPanel`, `NSOpenPanel`, ...) or coordinate with
/// a second window, its hide-on-blur behavior can stay this simple.
final class OverlayPanel: NSPanel {
    private var escMonitor: Any?
    private var isAnimating = false
    private var hostingView: NSHostingView<PanelContentView>!

    convenience init(store: DocumentStore, appearance: ShelfAppearanceStore) {
        let hostingView = NSHostingView(rootView: PanelContentView(store: store, appearance: appearance))
        hostingView.frame = CGRect(x: 0, y: 0, width: 720, height: 320)

        self.init(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.hostingView = hostingView
        self.contentView = hostingView
        configureAppearance()
    }

    /// Window size that exactly fits the current shelf content, queried
    /// fresh from SwiftUI itself (`NSHostingView.fittingSize`) rather than
    /// hand-replicated in AppKit — a previous manual width/height estimate
    /// (mirroring `PanelContentView`'s grid math by hand) drifted out of
    /// sync with the real layout and clipped content. `fittingSize`
    /// reflects the *current* `store.document` state (checking/unchecking
    /// a layout in the editor updates it, even while this window is
    /// off-screen — the hosting view's SwiftUI subscriptions stay live),
    /// so this needs no manual recomputation when that changes.
    private func contentSize(on screen: NSScreen) -> CGSize {
        let fitting = hostingView.fittingSize
        let visible = screen.visibleFrame
        // `PanelContentView` sizes itself to fit its own content (see its
        // `cardScale`), not a screen-relative target — this clamp is just a
        // safety net for screens too small/short to fit that natural size,
        // with enough margin to avoid ever touching the screen edges.
        return CGSize(width: min(fitting.width, visible.width - 24), height: min(fitting.height, visible.height - 80))
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
        let size = contentSize(on: screen)
        let x = visible.midX - size.width / 2
        // Parked just below the visible area so the slide-up is seamless.
        let y = visible.minY - size.height - 20
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func shownFrame(on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let size = contentSize(on: screen)
        let x = visible.midX - size.width / 2
        // `size.height` already includes `PanelContentView.bottomOverflow`
        // (it's real SwiftUI content, so `fittingSize` counts it). Parking
        // the panel exactly that far below the screen's bottom edge pushes
        // the overflow band — and the corner-radius curve inside it — off
        // the physical display, leaving a flush, square-bottomed panel on
        // screen. See `PanelContentView.bottomOverflow`'s doc comment.
        let y = visible.minY - PanelContentView.bottomOverflow
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
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
        hide()
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
