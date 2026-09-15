# KeyWii

A hotkey-triggered overlay panel for macOS that shows a visual reference
of your Corne keyboard layouts — slides up from the bottom third of the
screen, slides back down on Esc or on losing focus. Editing (keys,
layouts, the global shortcut) happens in a separate window, opened from
the status bar menu.

See **`AGENTS.md`** for the full design brief, locked-in decisions, and
known gaps — read that first if you're picking this project back up
after a break, or handing it to an agent.

## Requirements

- macOS 13+
- Xcode 15+ (for the Swift toolchain) — a **free** Apple ID is enough,
  no paid Developer Program membership needed for local builds/runs.

## Build & run

```bash
cd keywii
swift build
swift run
```

First run will prompt for macOS Accessibility/Input Monitoring
permission if needed by the global hotkey — grant it in
System Settings → Privacy & Security.

Default shortcut: **Option + Space** (changeable via the status bar
menu → Settings…).

## Using it

- Press the global shortcut to show/hide the read-only overlay panel —
  it just displays whichever layout you last selected.
- Use the status bar icon's menu for everything else: **Edit Layouts…**
  (add/rename/delete layouts, click any key to edit its content/tag/
  color), **Settings…** (record a new global shortcut), or **Quit**.

## Building a real .app (double-click launch)

```bash
Scripts/build_app.sh
open KeyWii.app
```

Builds a release binary, wraps it in `KeyWii.app` with a placeholder
icon, and ad-hoc `codesign`s it (still no paid Apple Developer account
needed). See `AGENTS.md` under "App bundling and icon" for details.

## Opening in Xcode

```bash
open Package.swift
```

Xcode will treat this as a Swift Package with an executable target —
you get full IDE support (breakpoints, previews for the SwiftUI views)
without needing a traditional `.xcodeproj`.

## Project layout

```
Sources/KeyWii/
  App/            NSApplication entry point, AppDelegate (hotkey + status
                   bar menu wiring), HotKeyPreference, DocumentStore+Binding
  Panel/          OverlayPanel (the read-only shelf) and
                   EditorWindowController (the real editor/settings window)
  Views/          PanelContentView (shelf), LayoutEditorView (editor),
                   KeyboardGridView (shared grid), KeyEditorView,
                   HotKeySettingsView, KeyCellView
  Models/         KeyContent, KeyLayout, CorneLayout, KeyWiiDocument,
                   DocumentStore, CorneV4Geometry, CodableColor
```

## Status

Core rendering model, real Corne v4 stagger geometry, tap-to-edit for
keys, layout add/remove/rename, a configurable global hotkey, a status
bar icon, and `.app` bundling are all in place. Full list of any
remaining gaps in `AGENTS.md` under "Not yet built."
