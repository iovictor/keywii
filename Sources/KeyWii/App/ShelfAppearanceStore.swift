import SwiftUI
import Combine

/// Persists the shelf's background/border color choices in `UserDefaults`
/// — an app-level appearance preference, not document data, so it
/// deliberately doesn't live in `KeyWiiDocument`/`document.json`. Shared
/// (one instance) between `PanelContentView` (reads it to draw the shelf)
/// and `HotKeySettingsView` (writes it via `ColorPicker`s) so a change
/// in Settings is reflected the next time the shelf is shown.
final class ShelfAppearanceStore: ObservableObject {
    private static let backgroundKey = "KeyWiiShelfBackgroundColor"
    private static let borderKey = "KeyWiiShelfBorderColor"
    private static let layoutBorderKey = "KeyWiiShelfLayoutBorderColor"
    private static let cardScaleKey = "KeyWiiShelfCardScale"

    static let defaultBackground = CodableColor(red: 0.11, green: 0.11, blue: 0.13)
    static let defaultBorder = CodableColor(red: 1, green: 1, blue: 1, alpha: 0.12)
    /// Border drawn around each individual layout card, distinct from
    /// `border` (the outer panel's own edge) — a bit brighter by default
    /// so cards read as separate even against a similarly-dark panel
    /// background.
    static let defaultLayoutBorder = CodableColor(red: 1, green: 1, blue: 1, alpha: 0.2)
    /// Per-mini-board scale used by `PanelContentView.scaledGrid(for:)`.
    /// 1.0 is the board's true native size and the last value confirmed
    /// crisp — `.scaleEffect` scales the already-rasterized layer, so
    /// going above 1 stretches existing pixels and starts to blur the
    /// text. The range intentionally reaches past 1.0 so the slider can
    /// be used to find exactly where that blur becomes noticeable,
    /// rather than hard-capping it before the user can see for themselves.
    static let defaultCardScale: CGFloat = 1.0
    static let cardScaleRange: ClosedRange<CGFloat> = 0.4...1.8

    @Published var background: CodableColor {
        didSet { Self.save(background, forKey: Self.backgroundKey) }
    }
    @Published var border: CodableColor {
        didSet { Self.save(border, forKey: Self.borderKey) }
    }
    @Published var layoutBorder: CodableColor {
        didSet { Self.save(layoutBorder, forKey: Self.layoutBorderKey) }
    }
    @Published var cardScale: CGFloat {
        didSet { UserDefaults.standard.set(Double(cardScale), forKey: Self.cardScaleKey) }
    }

    init() {
        background = Self.load(forKey: Self.backgroundKey) ?? Self.defaultBackground
        border = Self.load(forKey: Self.borderKey) ?? Self.defaultBorder
        layoutBorder = Self.load(forKey: Self.layoutBorderKey) ?? Self.defaultLayoutBorder
        let storedScale = UserDefaults.standard.object(forKey: Self.cardScaleKey) as? Double
        cardScale = storedScale.map { CGFloat($0) } ?? Self.defaultCardScale
    }

    private static func load(forKey key: String) -> CodableColor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CodableColor.self, from: data)
    }

    private static func save(_ color: CodableColor, forKey key: String) {
        guard let data = try? JSONEncoder().encode(color) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
