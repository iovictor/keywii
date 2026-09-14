# Tassel

A hotkey-triggered overlay panel for macOS that shows a visual reference
of your Corne keyboard layouts — slides up from the bottom third of the
screen, slides back down on Esc or on losing focus.

See **`AGENTS.md`** for the full design brief, locked-in decisions, and
known gaps — read that first if you're picking this project back up
after a break, or handing it to an agent.

## Requirements

- macOS 13+
- Xcode 15+ (for the Swift toolchain) — a **free** Apple ID is enough,
  no paid Developer Program membership needed for local builds/runs.

## Build & run

```bash
cd tassel
swift build
swift run
```

First run will prompt for macOS Accessibility/Input Monitoring
permission if needed by the global hotkey — grant it in
System Settings → Privacy & Security.

Default shortcut: **Option + Space** (hardcoded for now in
`Sources/Tassel/App/AppDelegate.swift`).

## Building a real .app (double-click launch)

```bash
Scripts/build_app.sh
open Tassel.app
```

Builds a release binary, wraps it in `Tassel.app` with a placeholder
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
Sources/Tassel/
  App/            NSApplication entry point + AppDelegate (hotkey wiring)
  Panel/          OverlayPanel — the NSPanel subclass with slide animation
  Views/          SwiftUI views (KeyCellView, PanelContentView)
  Models/         KeyContent, KeyLayout, CorneLayout, TasselDocument, DocumentStore
```

## Status

Core rendering model, the show/hide panel mechanics, real Corne v4
stagger geometry, tap-to-edit for keys, layout add/remove/rename, and
`.app` bundling are all in place. Not yet built: a user-configurable
hotkey. Full list in `AGENTS.md` under "Not yet built."
