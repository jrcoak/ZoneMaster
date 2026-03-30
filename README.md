# ZoneMaster

A macOS menu bar app that divides a single monitor into virtual "zones" that behave like separate screens.

## What it does

- **Window constraining** — Maximize fills only the zone a window is in, not the whole screen
- **Capture frame sharing** — Share a single zone in Zoom/Teams/Meet via the "Share Window" picker
- **Switchable profiles** — Named layouts (e.g., "Presenting", "Coding") switchable via menu bar or hotkey
- **Preset + custom layouts** — 6 built-in presets or drag dividers to create your own
- **Sticky edges** — Configurable resistance when dragging windows across zone boundaries
- **Global keyboard shortcuts** — Move windows between zones, toggle zones, switch profiles

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permissions (prompted on first launch)

## Building

Open `ZoneMaster.xcodeproj` in Xcode 15+ and build (⌘B). No external dependencies.

## How capture frame sharing works

Each zone can have an associated "capture frame" — an invisible, click-through window sized to the zone's bounds. When you open Zoom/Teams/Meet and choose "Share Window", you'll see entries like "ZoneMaster — Zone 1". Sharing that window captures exactly the zone's region. Capture frame settings persist across app restarts.

## Architecture

```
ZoneMaster/
├── Models/          # Zone, Profile, ZoneLayout data models
├── Services/        # Zone engine, accessibility, capture frames, shortcuts
│   ├── ZoneEngine.swift           # Central coordinator
│   ├── ZoneEnforcer.swift         # Accessibility-based window constraining
│   ├── AccessibilityService.swift # AXUIElement wrapper
│   ├── CaptureFrameWindow.swift   # Borderless window for screen sharing
│   ├── CaptureFrameManager.swift  # Capture frame lifecycle
│   ├── DividerOverlayWindow.swift # Visual zone dividers
│   ├── ShortcutService.swift      # Global hotkey registration
│   └── ProfileStore.swift         # JSON persistence
└── Views/           # SwiftUI views
    ├── MenuBar/     # Menu bar dropdown
    └── Settings/    # Zone config, profiles, preferences
```

The zone enforcement layer is behind a `ZoneEnforcerProtocol`, designed to be swappable for a virtual display driver in the future.

## License

MIT
