import Foundation

/// A named configuration of zones, capture frame settings, and visual preferences.
/// Users switch between profiles for different workflows (e.g., "Presenting", "Coding").
struct Profile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var zones: [Zone]
    var layoutSource: ZoneLayoutSource
    var showDividers: Bool
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        zones: [Zone],
        layoutSource: ZoneLayoutSource = .preset(.threeEqualColumns),
        showDividers: Bool = true,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.zones = zones
        self.layoutSource = layoutSource
        self.showDividers = showDividers
        self.isDefault = isDefault
    }

    /// Create a default profile with 3 equal columns
    static func makeDefault() -> Profile {
        let preset = ZonePreset.threeEqualColumns
        return Profile(
            name: "Default",
            zones: preset.generateZones(),
            layoutSource: .preset(preset),
            showDividers: true,
            isDefault: true
        )
    }

    /// Duplicate this profile with a new name
    func duplicate(newName: String) -> Profile {
        Profile(
            name: newName,
            zones: zones.map { zone in
                Zone(
                    normalizedRect: zone.normalizedRect,
                    name: zone.name,
                    captureFrameEnabled: zone.captureFrameEnabled
                )
            },
            layoutSource: layoutSource,
            showDividers: showDividers,
            isDefault: false
        )
    }
}

/// Top-level persisted state
struct AppState: Codable {
    var profiles: [Profile]
    var activeProfileId: UUID
    var zonesEnabled: Bool
    var stickyEdgesEnabled: Bool
    var stickyEdgeThreshold: Double // pixels of resistance before crossing
    var launchAtLogin: Bool

    static func makeDefault() -> AppState {
        let defaultProfile = Profile.makeDefault()
        return AppState(
            profiles: [defaultProfile],
            activeProfileId: defaultProfile.id,
            zonesEnabled: true,
            stickyEdgesEnabled: true,
            stickyEdgeThreshold: 20.0,
            launchAtLogin: true
        )
    }
}

/// User-configured keyboard shortcut
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt // NSEvent.ModifierFlags.rawValue
    var displayString: String // Human-readable, e.g. "⌃⌥→"

    static let empty = KeyboardShortcut(keyCode: 0, modifiers: 0, displayString: "")
}

/// All configurable shortcuts
struct ShortcutBindings: Codable {
    var moveToNextZone: KeyboardShortcut
    var moveToPreviousZone: KeyboardShortcut
    var moveToZone1: KeyboardShortcut
    var moveToZone2: KeyboardShortcut
    var moveToZone3: KeyboardShortcut
    var moveToZone4: KeyboardShortcut
    var toggleZones: KeyboardShortcut
    var nextProfile: KeyboardShortcut

    static func makeDefault() -> ShortcutBindings {
        // Default: Ctrl+Opt+Arrow for zone movement, Ctrl+Opt+Z for toggle
        ShortcutBindings(
            moveToNextZone: KeyboardShortcut(keyCode: 124, modifiers: 0x180000, displayString: "⌃⌥→"),
            moveToPreviousZone: KeyboardShortcut(keyCode: 123, modifiers: 0x180000, displayString: "⌃⌥←"),
            moveToZone1: KeyboardShortcut(keyCode: 18, modifiers: 0x180000, displayString: "⌃⌥1"),
            moveToZone2: KeyboardShortcut(keyCode: 19, modifiers: 0x180000, displayString: "⌃⌥2"),
            moveToZone3: KeyboardShortcut(keyCode: 20, modifiers: 0x180000, displayString: "⌃⌥3"),
            moveToZone4: KeyboardShortcut(keyCode: 21, modifiers: 0x180000, displayString: "⌃⌥4"),
            toggleZones: KeyboardShortcut(keyCode: 6, modifiers: 0x180000, displayString: "⌃⌥Z"),
            nextProfile: KeyboardShortcut(keyCode: 35, modifiers: 0x180000, displayString: "⌃⌥P")
        )
    }
}
