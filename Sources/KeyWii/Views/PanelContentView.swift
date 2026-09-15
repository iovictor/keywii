import SwiftUI

/// Root view of the hotkey-triggered overlay panel — a pure, read-only
/// display. Every layout marked `isVisibleOnShelf` shows here
/// *simultaneously* as its own labeled mini-board, laid out in a grid up
/// to `maxColumns` per row (not a tab strip you switch between — that
/// changed from an earlier iteration once it turned out "checked" was
/// meant as "shown here" rather than "selectable here"). No editing
/// lives here at all (not even a settings button) — that's deliberate,
/// see AGENTS.md's "Editor architecture" section. All editing happens in
/// the separate `LayoutEditorView` window, opened from the status bar
/// menu — including which layouts are checked to appear here.
struct PanelContentView: View {
    @ObservedObject var store: DocumentStore
    @ObservedObject var appearance: ShelfAppearanceStore

    static let maxColumns = 3
    private static let gridSpacing: CGFloat = 32
    private static let outerPadding: CGFloat = 16
    /// Extra transparent-background-matching height tacked onto the very
    /// bottom of the panel, past the visible content — `OverlayPanel`
    /// positions the shown panel so exactly this much of its bottom edge
    /// sits below the screen's own bottom edge. The corner-radius curve
    /// lives inside this overflow band, so it ends up rendered off-screen
    /// while the rest of the panel is on it — the visible result is a
    /// panel that looks flush against the screen edge with square bottom
    /// corners, rounded only on top, without needing `UnevenRoundedRectangle`
    /// (macOS 14+; this app targets macOS 13). Must exceed the corner
    /// radius (14) so the curve fully clears the screen edge.
    static let bottomOverflow: CGFloat = 32
    /// Padding between each mini-board and its own `layoutBorder` outline.
    private static let cardBorderPadding: CGFloat = 8
    /// Extra bottom-only padding inside each layout's border, beyond
    /// `cardBorderPadding` — the thumb-key row sits close to the board's
    /// bottom edge, so a little more breathing room there (vs. top/sides)
    /// keeps the border from feeling like it's crowding those keys.
    private static let cardBorderBottomExtra: CGFloat = 10

    private var visibleLayouts: [CorneLayout] {
        store.document.layouts.filter { $0.isVisibleOnShelf }
    }

    /// Balances the grid so the last row is never a lonely leftover — e.g.
    /// 4 visible layouts becomes 2 rows of 2, not a row of 3 plus a row of
    /// 1. Standard "balanced grid" trick: cap columns at `maxColumns`,
    /// compute how many rows that needs, then shrink columns to the
    /// fewest that still fit everyone in that same row count. With at
    /// most `KeyWiiDocument.maxLayouts` (5) items ever in play, this never
    /// needs to consider more rows than that starting point produces.
    private var columnCount: Int {
        let count = visibleLayouts.count
        guard count > 0 else { return 1 }
        let initialColumns = min(Self.maxColumns, count)
        let rows = Int((Double(count) / Double(initialColumns)).rounded(.up))
        return Int((Double(count) / Double(rows)).rounded(.up))
    }

    /// User-adjustable via the Settings slider (see `ShelfAppearanceStore.cardScale`)
    /// — the slider intentionally allows values above 1.0 (the board's
    /// true native size) so blur from upscaling can be dialed in and
    /// found deliberately, rather than being hard-capped away.
    private var cardWidth: CGFloat {
        CorneV4Geometry.boardSize.width * appearance.cardScale
    }

    /// `visibleLayouts` chunked into rows of `columnCount`.
    private var rows: [[CorneLayout]] {
        stride(from: 0, to: visibleLayouts.count, by: columnCount).map {
            Array(visibleLayouts[$0..<min($0 + columnCount, visibleLayouts.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if visibleLayouts.isEmpty {
                    Text("No layouts shown — check one in Edit Layouts")
                        .foregroundStyle(.secondary)
                        .padding(16)
                } else {
                    // `Grid`, not `LazyVGrid` — the "lazy" grids are built for
                    // use inside a `ScrollView` with a bounded viewport, and
                    // report an incorrect (very large) natural size when
                    // queried outside one via `NSHostingView.fittingSize`
                    // (confirmed as a cause of the shelf rendering its
                    // content squished into the top of a mostly-empty, far
                    // too tall window). With at most 5 items there's no
                    // laziness to gain from anyway.
                    Grid(alignment: .top, horizontalSpacing: Self.gridSpacing, verticalSpacing: Self.gridSpacing) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            GridRow {
                                ForEach(rows[rowIndex]) { layout in
                                    VStack(spacing: 6) {
                                        Text(layout.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                        scaledGrid(for: layout)
                                            .padding(.horizontal, Self.cardBorderPadding)
                                            .padding(.top, Self.cardBorderPadding)
                                            .padding(.bottom, Self.cardBorderPadding + Self.cardBorderBottomExtra)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(appearance.layoutBorder.color, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(Self.outerPadding)
                }
            }

            // See `bottomOverflow`'s doc comment — this band is pushed
            // below the screen edge by `OverlayPanel`, taking the
            // corner-radius curve with it.
            Color.clear.frame(height: Self.bottomOverflow)
        }
        .background(appearance.background.color)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(appearance.border.color, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// `KeyboardGridView` at its real (large) size, scaled down to fit
    /// `cardWidth` — `.scaleEffect` alone doesn't change layout size, so
    /// the surrounding frame is set explicitly to the scaled dimensions.
    ///
    /// Both frames need explicit `alignment: .topLeading`. `.scaleEffect`
    /// never changes a view's *reported layout size* — after it, this view
    /// still claims to be the full, unscaled `boardSize` for layout
    /// purposes. The outer frame below is much smaller than that, and with
    /// the default `.center` alignment it was placing the (still
    /// full-size) child centered inside that small box — shifting it up
    /// and to the left — *before* `.scaleEffect(anchor: .topLeading)`
    /// scaled the rendering down around its own (now off-center) corner.
    /// The two offsets fought each other: only a top-left sliver of the
    /// board ended up inside the small box, with the rest of the visually
    /// scaled content spilling outside it — this was the actual cause of
    /// "keys only visible near the top, empty space below" once diagnosed
    /// with a debug border. Pinning both frames to `.topLeading` removes
    /// the centering offset so the scale anchor has nothing to fight.
    private func scaledGrid(for layout: CorneLayout) -> some View {
        let boardSize = CorneV4Geometry.boardSize
        let scale = cardWidth / boardSize.width
        return KeyboardGridView(layout: layout)
            .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: boardSize.width * scale, height: boardSize.height * scale, alignment: .topLeading)
    }
}
