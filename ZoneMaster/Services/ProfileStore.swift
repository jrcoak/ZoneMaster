import Foundation
import Combine

/// Manages profile and app state persistence to ~/Library/Application Support/ZoneMaster/
final class ProfileStore: ObservableObject {
    @Published var appState: AppState
    @Published var shortcutBindings: ShortcutBindings

    private let stateFileURL: URL
    private let shortcutsFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var activeProfile: Profile {
        get {
            appState.profiles.first { $0.id == appState.activeProfileId }
                ?? appState.profiles.first
                ?? Profile.makeDefault()
        }
        set {
            if let index = appState.profiles.firstIndex(where: { $0.id == newValue.id }) {
                appState.profiles[index] = newValue
                save()
            }
        }
    }

    init() {
        let appSupportDir = Self.appSupportDirectory()
        self.stateFileURL = appSupportDir.appendingPathComponent("state.json")
        self.shortcutsFileURL = appSupportDir.appendingPathComponent("shortcuts.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Load or create defaults
        if let data = try? Data(contentsOf: stateFileURL),
           let state = try? decoder.decode(AppState.self, from: data) {
            self.appState = state
        } else {
            self.appState = AppState.makeDefault()
        }

        if let data = try? Data(contentsOf: shortcutsFileURL),
           let shortcuts = try? decoder.decode(ShortcutBindings.self, from: data) {
            self.shortcutBindings = shortcuts
        } else {
            self.shortcutBindings = ShortcutBindings.makeDefault()
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            let stateData = try encoder.encode(appState)
            try stateData.write(to: stateFileURL, options: .atomic)

            let shortcutsData = try encoder.encode(shortcutBindings)
            try shortcutsData.write(to: shortcutsFileURL, options: .atomic)
        } catch {
            print("ZoneMaster: Failed to save state: \(error)")
        }
    }

    // MARK: - Profile Management

    func createProfile(name: String, from preset: ZonePreset) -> Profile {
        let profile = Profile(
            name: name,
            zones: preset.generateZones(),
            layoutSource: .preset(preset)
        )
        appState.profiles.append(profile)
        save()
        return profile
    }

    func duplicateProfile(_ profile: Profile) -> Profile {
        let newProfile = profile.duplicate(newName: "\(profile.name) Copy")
        appState.profiles.append(newProfile)
        save()
        return newProfile
    }

    func deleteProfile(_ profile: Profile) {
        guard appState.profiles.count > 1 else { return } // Keep at least one
        appState.profiles.removeAll { $0.id == profile.id }

        // If we deleted the active profile, switch to the first remaining one
        if appState.activeProfileId == profile.id {
            appState.activeProfileId = appState.profiles.first!.id
        }

        // Ensure at least one profile is default
        if !appState.profiles.contains(where: { $0.isDefault }) {
            appState.profiles[0].isDefault = true
        }

        save()
    }

    func renameProfile(_ profile: Profile, to newName: String) {
        if let index = appState.profiles.firstIndex(where: { $0.id == profile.id }) {
            appState.profiles[index].name = newName
            save()
        }
    }

    func setActiveProfile(_ profile: Profile) {
        appState.activeProfileId = profile.id
        save()
    }

    func switchToNextProfile() {
        guard appState.profiles.count > 1 else { return }
        let currentIndex = appState.profiles.firstIndex { $0.id == appState.activeProfileId } ?? 0
        let nextIndex = (currentIndex + 1) % appState.profiles.count
        appState.activeProfileId = appState.profiles[nextIndex].id
        save()
    }

    func updateZones(_ zones: [Zone], for profileId: UUID) {
        if let index = appState.profiles.firstIndex(where: { $0.id == profileId }) {
            appState.profiles[index].zones = zones
            save()
        }
    }

    func setLayoutSource(_ source: ZoneLayoutSource, for profileId: UUID) {
        if let index = appState.profiles.firstIndex(where: { $0.id == profileId }) {
            appState.profiles[index].layoutSource = source
            save()
        }
    }

    func toggleCaptureFrame(zoneId: UUID, profileId: UUID) {
        if let profileIndex = appState.profiles.firstIndex(where: { $0.id == profileId }),
           let zoneIndex = appState.profiles[profileIndex].zones.firstIndex(where: { $0.id == zoneId }) {
            appState.profiles[profileIndex].zones[zoneIndex].captureFrameEnabled.toggle()
            save()
        }
    }

    // MARK: - App State

    func toggleZonesEnabled() {
        appState.zonesEnabled.toggle()
        save()
    }

    func setStickyEdges(enabled: Bool) {
        appState.stickyEdgesEnabled = enabled
        save()
    }

    func setStickyEdgeThreshold(_ threshold: Double) {
        appState.stickyEdgeThreshold = threshold
        save()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        appState.launchAtLogin = enabled
        save()
    }

    // MARK: - Helpers

    private static func appSupportDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ZoneMaster")
    }
}
