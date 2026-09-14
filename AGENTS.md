# Tassel — Agent Instructions

This file orients any AI coding agent (Claude Code, etc.) working in this
repo. Read it before making changes. Update it when a decision below
changes or a new one is made — keep it in sync with reality, not with
what was originally planned.

## What this app is

A macOS menu-less utility that shows a hotkey-triggered overlay panel
displaying a visual reference of the user's Corne keyboard layout(s) —
up to 5 layouts ("layers"), each a grid of keys with custom
icon/text/color per key. Purpose: glance at custom keybindings without
tabbing away from work.

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
| **`NSPanel` (`.nonactivatingPanel`, `.floating` level)**, hosting a SwiftUI view via `NSHostingView` | Doesn't steal focus from the frontmatter app when shown; floats above normal windows; SwiftUI still used for all actual UI/layout. |
| **JSON file persistence** (`~/Library/Application Support/Tassel/document.json`) via `Codable`, not CoreData/SwiftData | Data model is small (≤5 layouts × modest key counts) and doesn't need queries, migrations, or undo history yet. Revisit only if per-key edit history is wanted later. |
| **`.accessory` activation policy** | No Dock icon, no Cmd-Tab entry — pure background utility, consistent with "hidden until summoned" design. |

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

Invalid state: **secondary present with no primary is never allowed.**
This is enforced in `KeyEditorView` two ways: the "Secondary" toggle is
disabled while primary is empty, and clearing primary also clears
secondary (see `KeyEditorView.primaryBinding`). See also
`KeyLayout.isValid` in `Models/KeyLayout.swift` — extend it if a
stricter check is ever needed.

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
  `PanelContentView` looks up each key's placement live from
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
  the panel always renders every physical key position, not just ones
  with data. New layouts (once add/rename UI exists) should be seeded
  via `corneV4Base`, not an empty `keys: []`.

## Panel behavior decisions

- Slides up from the **bottom third** of the main screen on the global
  hotkey (default: Option+Space, see `AppDelegate.hotKey` — not yet
  user-configurable, that's a known next step).
- Slides back down and hides on: **Esc key** (local monitor, swallows
  the event) or **losing key window status** (`resignKey`, i.e.
  clicking elsewhere / switching apps).
- Toggle behavior: pressing the hotkey again while shown hides it
  (see `OverlayPanel.toggle()`).
- Up to **5 layouts** max (`TasselDocument.maxLayouts`), switchable via
  the tab strip at the top of the panel. Each tab (`LayoutTab` in
  `PanelContentView.swift`) supports select-on-tap, inline rename (the
  active tab's pencil button swaps the label for a `TextField`), and
  delete (hidden when only one layout remains — always keep at least
  one). A new layout is seeded via `CorneLayout.corneV4Base`, never an
  empty `keys: []`, so it starts as the full 46-slot board.
  **Rename-commit gotcha**: don't rely on `@FocusState` losing focus to
  detect "clicked away" — clicking a plain (non-text-input) SwiftUI view
  in this AppKit-hosted panel doesn't reliably resign the `TextField`'s
  first-responder status, so the rename can silently stay open forever.
  Rename state lives in `PanelContentView` (not the tab itself), and
  every other panel action (select/add/delete a layout, tap a key)
  explicitly calls `commitRename()` first — that's what actually commits
  a pending rename, not focus tracking.
- **Tapping a key opens an inline editor** (`KeyEditorView.swift`) — a
  dimmed backdrop + card rendered *inside* the same panel via
  `.overlay`, not a `.sheet`/separate window. This is deliberate: a real
  child window becoming key would trip `OverlayPanel.resignKey` and
  auto-hide the panel out from under the editor. The one unavoidable
  native modal (the `NSOpenPanel` image-file picker in
  `ImagePickerRow.pickImage`) sets `OverlayPanel.suppressAutoHide` for
  its duration via the `\.overlayPanel` environment key — follow that
  pattern for any future native modal invoked from panel content.

## App bundling and icon

- `Scripts/build_app.sh` builds a release binary and wraps it in a real
  `Tassel.app` (Info.plist, `LSUIElement=true` so it never flashes a Dock
  icon even before `NSApp.setActivationPolicy(.accessory)` runs,
  ad-hoc-`codesign`ed — no paid Apple Developer account needed, per the
  non-negotiable constraints above). Run it, then `open Tassel.app` or
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

## Not yet built (known gaps — check before assuming these exist)

- User-configurable global hotkey (currently hardcoded in
  `AppDelegate`).

## Conventions

- Keep `Models/` free of AppKit/SwiftUI imports where possible
  (`CodableColor` is the one necessary exception, for `NSColor`
  bridging) — models should stay platform-plain and testable.
- Don't reintroduce per-content-type sizing conditionals in
  `KeyCellView` — sizing is presence-of-secondary only, per the
  locked-in rule above.
- Persist via `DocumentStore.save()`, called on
  `applicationWillTerminate` — if you add editing UI, also call
  `save()` after each committed edit rather than relying solely on
  termination.
