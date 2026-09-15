# KeyWii — Agent Instructions

This file orients any AI coding agent (Claude Code, etc.) working in this
repo. Read it before making changes. Update it when a decision below
changes or a new one is made — keep it in sync with reality, not with
what was originally planned.

## What this app is

A macOS menu-less utility with two surfaces: a hotkey-triggered overlay
panel (the "shelf") that displays a read-only visual reference of the
user's Corne keyboard layout(s) — up to 5 layouts ("layers"), each a grid
of keys with custom icon/text/color per key — and a separate "Edit
Layouts" window (opened from the status bar menu) where all editing
happens. Purpose: glance at custom keybindings without tabbing away from
work, and edit them in a proper window when needed.

Reference project for the physical key layout/stagger geometry:
`/Users/victor/Sites/sandbox/corne-v4-visualizer`. Its column-stagger and
thumb-arc geometry (from `public/styles.css`) has been ported into
`Models/CorneV4Geometry.swift`, scaled down from its 100pt keycaps to
this panel's smaller ones — see "Physical geometry decisions" below.

## Non-negotiable constraints

- **No paid Apple Developer account.** Everything must build and run
  locally via free-tier code signing (Xcode automatic signing with a
  free Apple ID, or ad-hoc `codesign` from the CLI). Do not introduce
  anything that requires notarization or a paid account (e.g. certain
  entitlements, Mac App Store distribution APIs).
- **Solo-use app.** No need for multi-user accounts, cloud sync,
  crash reporting, analytics, or App Store review compliance. Optimize
  for "works reliably for one person" over "productizable."
- **Low idle resource footprint** was an explicit design driver in
  choosing the stack (see below) — don't casually add background
  polling, timers, or heavyweight frameworks without a reason tied to
  a real feature.

## Stack decisions (and why)

| Decision | Reason |
|---|---|
| **Native SwiftUI + AppKit**, not Tauri/Electron/Hammerspoon | User has no use for Hammerspoon and doesn't mind a from-scratch rebuild since this is solo-use. Native gives the lightest idle footprint and best animation feel; avoided Electron specifically for its Chromium memory cost. |
| **Swift Package Manager**, not an `.xcodeproj` | Fully text-based project definition — buildable/runnable via `swift build` / `swift run` without Xcode project file complexity. Can still be opened directly in Xcode (`open Package.swift`) if a GUI is wanted later. |
| **HotKey package** (`soffes/HotKey`) for the global shortcut | Thin, well-maintained wrapper over Carbon's `RegisterEventHotKey`. No Accessibility permission required just for a hotkey (unlike some global-event-tap approaches). |
| **`NSPanel` (`.nonactivatingPanel`, `.floating` level)**, hosting a SwiftUI view via `NSHostingView` | Doesn't steal focus from the frontmost app when shown; floats above normal windows; SwiftUI still used for all actual UI/layout. |
| **JSON file persistence** (`~/Library/Application Support/KeyWii/document.json`) via `Codable`, not CoreData/SwiftData | Data model is small (≤5 layouts × modest key counts) and doesn't need queries, migrations, or undo history yet. Revisit only if per-key edit history is wanted later. |
| **`.accessory` activation policy** | No Dock icon, no Cmd-Tab entry — pure background utility. A status bar icon (see below) is the one always-visible affordance, mainly so there's a way to quit without a terminal. |

## Editor architecture (locked in via conversation — do not silently change)

This went through several failed iterations before landing here — read
this before touching panel/editor code.

- **The shelf (`OverlayPanel`/`PanelContentView`) is pure display.** No
  tap-to-edit, no settings button, nothing interactive beyond switching
  which layout tab you're looking at. It hides on Esc or on losing key
  window status (`resignKey`), full stop — no exceptions, no
  `NSApp.keyWindow` checks.
- **All editing lives in one real, separate `NSWindow`**
  (`EditorWindowController`, hosting `LayoutEditorView` for
  layouts/keys or `HotKeySettingsView` for the shortcut), opened only
  from the status bar menu ("Edit Layouts…" / "Settings…") — never from
  the shelf. `LayoutEditorView` puts the layout tab strip (with
  add/rename/delete) and the keyboard grid (`KeyboardGridView`, shared
  with the shelf) on top, and the selected key's edit fields
  (`KeyEditorView`) docked along the bottom, updating live as you click
  different keys.
- **Why this split exists**: `OverlayPanel`'s entire design is to
  disappear the instant it loses focus. Every attempt to host editing
  *inside* it — an inline overlay card, a small popup `NSWindow` opened
  from a shelf click — fought that design: `ColorPicker`'s
  `NSColorPanel` and `NSOpenPanel` becoming key tripped the auto-hide;
  working around that with `NSApp.keyWindow`-based heuristics and
  `escOverride` plumbing got fragile fast, and calling
  `NSApp.activate(ignoringOtherApps:)` to make a popup truly key
  triggered a third-party KVM/input-sharing utility's own focus-change
  popup, which looked like the shelf randomly closing. A real,
  independently-opened editor window sidesteps all of it: it has normal
  activation, so native modals just work, and the shelf never needs to
  reason about it at all.
- **`EditorWindowController` is one reused instance** for both
  `LayoutEditorView` and `HotKeySettingsView` — its content view is
  swapped per `show(title:content:)` call. It still needs
  `NSApp.activate(ignoringOtherApps: true)` when showing (confirmed
  empirically, twice: once that omitting it leaves the window ordered
  front but never truly key, and again that `NSApp.isActive` is still
  `false` even right after a status-bar-menu click, so a conditional
  "only activate if not already active" is a no-op here, not a fix).
  This activation is a normal, unavoidable "app became active" event —
  if a third-party KVM/input-sharing utility (e.g. Deskflow) pops its
  own UI in response every time the editor opens/closes, that's it
  reacting to an ordinary macOS app switch, not a bug on this app's
  side, and not something avoidable while keeping the window
  interactive. Its `escOverride` exists only for nested modal-like
  state within its content (e.g. `HotKeySettingsView`'s shortcut
  recorder wants Esc to cancel recording, not close the whole window)
  — don't repurpose it for anything shelf-related.
- **`LayoutEditorView.keyEditorSection` reserves a fixed `minHeight`
  (320) whether or not a key is selected.** `EditorWindowController.show()`
  sizes the window exactly once, from `NSHostingView.fittingSize` at the
  moment it opens — before any key is selected, when this section is
  just the short "click a key" placeholder. If the section were allowed
  to report a *taller* natural size once a key got selected (the real
  `KeyEditorView`, with Secondary toggle + Tag + color picker, is much
  taller), the window wouldn't grow to match: SwiftUI just renders the
  taller content squeezed into the original fixed window bounds,
  clipping or overlapping its bottom fields. Confirmed as the cause of
  a "wonky"-to-click Secondary checkbox and a seemingly-inert image
  picker button — both were landing partly outside the window's actual
  bounds. Keep both branches (placeholder and real editor) reserving
  the same height so the window's one-time sizing stays correct
  regardless of selection state.

## Key data model decisions (locked in via conversation — do not silently change)

A key has:
- **`primary`** (required): `.text(String)` or `.image(Data)`
- **`secondary`** (optional): `.text(String)` or `.image(Data)`, independent of primary's type — **all four combinations of primary/secondary type are valid** (text+text, text+image, image+text, image+image)
- **`tag`** (optional, always text): bottom-right corner, fixed position regardless of everything else
- **`backgroundColor`**: per-key custom color

Sizing rule (deliberately simplified for visual consistency across the
grid — do not reintroduce per-content-type sizing branches):
- **Secondary absent** → primary fills the key.
- **Secondary present** (regardless of whether primary/secondary are
  text or image, in any combination) → primary is fixed at ~70% height,
  secondary at ~30%, always stacked vertically in that order.
- This means a primary-image-only key and a primary-image+secondary-text
  key render their primary image at the *same* size — that uniformity
  was an explicit requirement, not an oversight.
- `KeyCellView` gives its content `.frame(width: geo.size.width, height:
  geo.size.height)` then `.clipped()` *before* anything else — without
  an explicit frame first, `.clipped()` crops a view to its own
  (potentially oversized) natural size, which is a no-op. This was a
  real bug: the 70/30 split's fixed spacing/padding overhead could push
  the VStack's natural height slightly past the key's actual height,
  visually enlarging the key whenever both primary and secondary were
  present. Keep the explicit frame-then-clip order.

Invalid state: **secondary present with no primary is never allowed.**
This is enforced in `KeyEditorView` two ways: the "Secondary" toggle is
disabled while primary is empty, and clearing primary also clears
secondary (see `KeyEditorView.primaryBinding`). See also
`KeyLayout.isValid` in `Models/KeyLayout.swift` — extend it if a
stricter check is ever needed.

**Image content sources**: `.image(Data)` is always flat, already-decoded
image bytes — never a file reference or icon handle — so a key's image
survives the source file/app being moved, renamed, or removed later.
`KeyEditorView`'s `ImagePickerRow` offers two ways to fill it: "Choose
Image…" (`NSOpenPanel` over an arbitrary file) or "From App…" (browse
`/Applications`, grab that app's own icon via `NSWorkspace.icon(forFile:)`,
then re-render it into a fixed-size PNG). Both end up as the same flat
`Data` — don't special-case "came from an app" anywhere downstream.

**Contrast**: foreground (text/icon) color per key is computed from
that key's own `backgroundColor` via relative luminance
(`CodableColor.contrastingForeground`), *not* from the system
light/dark mode setting. System appearance should only affect the
panel's own chrome (background material, switcher UI), never a key's
computed foreground — a bright key must stay readable in dark mode and
vice versa. Don't collapse these two concerns.

## Physical geometry decisions (locked in via conversation — do not silently change)

- `CorneV4Geometry.swift` defines the board's 46 fixed physical key slots
  (23 per half: 6 columns × 3 rows, minus the inner column's bottom row,
  plus 3 thumb keys), each with a stable string ID like `"L03"` or
  `"LT2"`, ported from the reference project's CSS `translateY` column
  stagger and thumb-arc `right/top/rotate` offsets.
- **Position is derived, never persisted.** `KeyLayout` stores only
  `slotID` + content (primary/secondary/tag/color) — no x/y/rotation.
  `KeyboardGridView` looks up each key's placement live from
  `CorneV4Geometry.slots` by `slotID` at render time. This was a
  deliberate fix after a real bug: an earlier version stored absolute
  `KeyPosition` per key in `document.json`, so a geometry constant tweak
  in code silently had no effect on an already-saved document (it kept
  using the frozen, stale coordinates). Do not reintroduce per-key
  stored position — if the board shape ever needs per-document
  overrides, that's a new, explicit feature, not a default.
- **Only the innermost thumb key per half is taller** (`thumbKeyHeight`,
  a 1.6x ratio ported from the source CSS's `--key-size-thumb` vs
  `--key-size`), and *only* in height — width is `keySize` for every
  key, thumb or not, matching the source CSS's `.key.thumb` rule (which
  overrides `height` only). Don't scale a thumb key's width to match.
- A layout is always the full 46-slot board (see
  `CorneLayout.corneV4Base`), even where a slot's content is empty —
  the grid always renders every physical key position, not just ones
  with data. New layouts should be seeded via `corneV4Base`, not an
  empty `keys: []`.
- **`KeyboardGridView`'s `ZStack` needs an explicit full-size
  `Color.clear` anchor child before any positioned keys.** Without it,
  the `ZStack`'s own reported layout size collapses to its largest
  single (un-positioned) child, and every key's tap gesture ends up
  hit-testing against that shared, tiny reference frame instead of its
  own true position — confirmed empirically as "only one key is
  clickable, and it's always the same one regardless of where you tap."
  Key taps also use a real `Button`, not `.onTapGesture` — the latter
  was tried first and hit the same misrouting.

## Panel (shelf) behavior decisions

- Slides up from the **bottom third** of the main screen on the global
  hotkey (default: Option+Space, user-configurable via the status bar
  menu → Settings…; see `HotKeyPreference` for persistence and
  `AppDelegate.registerHotKey` for re-registration).
- Slides back down and hides on: **Esc key** (local monitor, swallows
  the event) or **losing key window status** (`resignKey`, i.e.
  clicking elsewhere / switching apps) — unconditionally; see "Editor
  architecture" above for why this stays simple.
- Toggle behavior: pressing the hotkey again while shown hides it
  (see `OverlayPanel.toggle()`).
- Up to **5 layouts** max (`KeyWiiDocument.maxLayouts`); add/rename/
  delete/**reorder** live in the editor window's `LayoutTab` (in
  `LayoutEditorView.swift`) — the selected tab shows `‹`/`›` arrows that
  swap it with its neighbor (`LayoutEditorView.moveLayout`). Drag-and-drop
  was deliberately not used here (this app has hit multiple cases of
  custom SwiftUI gestures/pickers behaving unreliably on macOS — see "UI
  gotchas" below — so a plain, boring button is preferred for anything
  new). Order in `store.document.layouts` is also the order layouts
  appear in on the shelf's grid.
- **Layouts marked `isVisibleOnShelf` (toggled via the eye icon on each
  tab in "Edit Layouts") all display *simultaneously* on the shelf**, as
  scaled-down mini-boards in a `Grid` (`PanelContentView`, up to
  `maxColumns` — currently 3 — per row). This is not a tab strip you
  switch between; there is no "selected" layout concept on the shelf at
  all (only in the editor, for which one you're currently editing).
  `OverlayPanel.contentSize(on:)` computes the window's width/height
  fresh on every `show()` from `NSHostingView.fittingSize`, so
  checking/unchecking a layout (or reordering, or an appearance change)
  in the editor/Settings is reflected the next time the shelf appears —
  no live-resize plumbing needed since the shelf is always fully
  hidden/shown between edits.
  - **Column count balances itself** (`PanelContentView.columnCount`) so
    the last row is never a lonely leftover — e.g. 4 visible layouts
    becomes 2 rows of 2, not 3-then-1. Standard trick: cap columns at
    `maxColumns`, compute the row count that implies, then shrink columns
    to the fewest that still fit everyone in that same row count.
  - **Each mini-board is rendered at its true native size and then
    `.scaleEffect()`'d down** (`PanelContentView.scaledGrid(for:)`), not
    re-laid-out at a smaller size — `CorneV4Geometry`/`KeyCellView` have
    no scale parameter. `.scaleEffect` scales the already-rasterized
    layer, so a factor **over 1.0 upscales and visibly blurs the text**;
    this was hit twice (once when card width was derived from a fraction
    of the screen's own width divided across few columns, which worked
    out past 1x). The scale is user-adjustable — "Layout Size" slider in
    Settings, `ShelfAppearanceStore.cardScale`, persisted in
    `UserDefaults` — and the slider's range (`cardScaleRange`)
    deliberately extends a bit past 1.0 so the blur point can be found by
    eye rather than being hard-capped away.
  - Both `.frame()`s around `.scaleEffect()` in `scaledGrid(for:)` need
    explicit `alignment: .topLeading`. `.scaleEffect` never changes a
    view's *reported layout size* — it still claims its full, unscaled
    size for layout purposes. The outer frame is much smaller than that;
    with the default `.center` alignment it centered the still-full-size
    child inside the small frame (shifting it up-left) *before* the
    scale anchor (`.topLeading`) transformed the now off-center result —
    the two fought each other, so only a top-left sliver of each board
    ended up inside its box, looking like "empty space below tiny keys."
    Confirmed by a temporary debug border before the `.topLeading` fix.
  - **The shelf sits flush against the screen's bottom edge with square
    bottom corners**, not floating with a gap and fully rounded corners.
    `PanelContentView.bottomOverflow` (32pt, more than the 14pt corner
    radius) is extra transparent-background-matching height tacked onto
    the very bottom of the panel's content, and `OverlayPanel.shownFrame`
    positions the shown panel exactly that far below the screen's own
    bottom edge. The corner-radius curve lives inside that overflow band,
    so it renders off the physical display while the rest of the panel
    stays on it — cheaper than `UnevenRoundedRectangle` (macOS 14+; this
    app targets macOS 13).
  - Each mini-board also has its own light border
    (`appearance.layoutBorder`, also Settings-adjustable, distinct from
    the outer panel's own `appearance.border`) so cards read as separate
    even against a similarly-dark panel background. It gets extra
    bottom-only padding (`cardBorderBottomExtra`) since the thumb-key row
    otherwise crowds it.

## App bundling and icon

- `Scripts/build_app.sh` builds a release binary and wraps it in a real
  `KeyWii.app` (Info.plist, `LSUIElement=true` so it never flashes a
  Dock icon even before `NSApp.setActivationPolicy(.accessory)` runs,
  ad-hoc-`codesign`ed — no paid Apple Developer account needed, per the
  non-negotiable constraints above). Run it, then `open KeyWii.app` or
  double-click it in Finder.
- The icon is a placeholder (`Resources/AppIcon.icns`, generated by
  `Scripts/generate_icon.swift` into `Scripts/AppIcon.iconset/` then
  compiled with `iconutil`) — a dark rounded square with a simple
  split-key-cluster glyph. Regenerate via:
  ```
  swift Scripts/generate_icon.swift
  iconutil -c icns Scripts/AppIcon.iconset -o Resources/AppIcon.icns
  ```
  Replace this with a real design whenever one exists; nothing else
  needs to change (`build_app.sh` just copies whatever's at that path).

## UI gotchas hit in practice

- **A `.buttonStyle(.plain)` button with padding + a `.background()`
  shape (e.g. a capsule tab, a segmented-look toggle) only registers
  clicks on the label's own tight bounds — not the padded/colored area
  around it — unless you add `.contentShape(Rectangle())` (or
  `.contentShape(Capsule())` to match a non-rectangular background).
  Confirmed as a real, reported bug twice (the shelf's layout tabs, and
  `KeyEditorView`'s Text/Image toggle) before this was understood — add
  `.contentShape(...)` to any *new* button built this way from the
  start, matching the visual background's shape.
- **A `Picker` with `.pickerStyle(.segmented)` driven by a custom
  derived `Binding` (`Binding(get:set:)` computed from other state,
  rather than a plain `@State`/`@Binding` var) was unreliable on
  macOS** — clicking a segment fired the binding's setter repeatedly
  but the displayed selection kept snapping back, never visibly
  switching. Replaced with two plain `Button`s styled to look
  segmented (see `KeyEditorView.kindButton`) — prefer that pattern over
  a segmented `Picker` for any future text/image-style toggle here.
- **This app has no `NSApp.mainMenu` at all** (`.accessory`, no
  Dock icon, no window/app menu) — but *some* main menu is still
  required for standard Cmd-C/V/X/A to reach a focused `TextField`.
  AppKit checks the main menu for a matching key equivalent via
  `performKeyEquivalent` before a text view's own key-binding
  interpretation ever runs; with no main menu, those shortcuts silently
  do nothing anywhere in the app. `AppDelegate.setUpEditMenu()` installs
  a minimal, never-prominently-shown Edit menu (Cut/Copy/Paste/Select
  All/Undo/Redo) purely so `performKeyEquivalent` has something to
  match — don't remove it even though the menu bar it produces is
  mostly empty/unused visually.
- **`NSEvent.addLocalMonitorForEvents` installs an app-wide monitor, not
  a window-scoped one.** `EditorWindowController` originally removed its
  Esc-key monitor only right before installing a new one (on the next
  `show()`), never when the window actually closed — and closing via the
  native traffic-light button bypasses its own `closeWindow()` entirely,
  so that path never ran anyway. The leaked monitor kept intercepting
  every Esc keydown *app-wide* afterward and swallowing it (calling a
  no-op `closeWindow()`), which silently broke the shelf's own
  Esc-to-dismiss (`OverlayPanel`'s separate Esc monitor) the moment "Edit
  Layouts" or "Settings" had been opened once. Fixed by making
  `EditorWindowController` an `NSWindowDelegate` and removing the monitor
  in `windowWillClose`, which fires for every close path. Any future
  per-window local event monitor needs the same window-close cleanup —
  a `show()`-time `removeEscMonitor()` call is not enough on its own.
- **Sample seed data ported from `corne-v4-visualizer/data.json` used
  the wrong slot ID digit order** (`"{row}{column}"` from the source vs
  this project's `"{column}{row}"`) — see `CorneV4Geometry`'s and
  `CorneV4SampleData.swift`'s doc comments. Caused most of the board to
  either stack into the wrong column or get silently dropped ("half the
  keyboard is missing"). Double-check this conversion for any future
  reference-data porting.

## Not yet built (known gaps — check before assuming these exist)

Nothing currently tracked — the known gaps from earlier iterations
(tap-to-edit, layout management UI, real geometry, configurable hotkey,
a way to quit without a terminal) have all been built. Add new gaps here
as they come up.

## Conventions

- Keep `Models/` free of AppKit/SwiftUI imports where possible
  (`CodableColor` is the one necessary exception, for `NSColor`
  bridging). `DocumentStore+Binding.swift` and `HotKeyPreference.swift`
  live in `App/`, not `Models/`, specifically because they need
  SwiftUI's `Binding` / AppKit's `NSEvent`-adjacent `KeyCombo` type —
  models stay platform-plain and testable.
- Don't reintroduce per-content-type sizing conditionals in
  `KeyCellView` — sizing is presence-of-secondary only, per the
  locked-in rule above.
- Persist via `DocumentStore.save()`, called on
  `applicationWillTerminate` and after each committed edit in
  `LayoutEditorView`/`KeyEditorView` (via `DocumentStore.keyBinding`'s
  setter) — don't rely solely on termination for anything reachable
  from the editor window.
- When adding a new modal-like SwiftUI view hosted in
  `EditorWindowController`, follow `HotKeySettingsView`'s pattern for
  any nested Esc-cancel behavior (claim `editorWindowController?.escOverride`
  on `.onAppear`/state change, clear it on `.onDisappear`) rather than
  inventing a new mechanism.
