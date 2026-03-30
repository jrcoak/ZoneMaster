import SwiftUI

/// The menu bar dropdown content. Shows profile switcher, zone toggle,
/// capture frame controls, and settings access.
struct MenuBarView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var zoneEngine: ZoneEngine
    @ObservedObject var captureFrameManager: CaptureFrameManager

    let onOpenSettings: () -> Void
    let onOpenPreferences: () -> Void

    private var activeProfile: Profile {
        profileStore.activeProfile
    }

    var body: some View {
        VStack(spacing: 0) {
            // Zone toggle
            Button(action: {
                profileStore.toggleZonesEnabled()
                if profileStore.appState.zonesEnabled {
                    zoneEngine.activate(
                        with: activeProfile,
                        stickyEdgesEnabled: profileStore.appState.stickyEdgesEnabled,
                        stickyEdgeThreshold: profileStore.appState.stickyEdgeThreshold
                    )
                    captureFrameManager.syncFrames(
                        zones: activeProfile.zones,
                        screen: zoneEngine.targetScreen
                    )
                } else {
                    zoneEngine.deactivate()
                    captureFrameManager.hideAll()
                }
            }) {
                HStack {
                    Image(systemName: profileStore.appState.zonesEnabled ? "checkmark.square.fill" : "square")
                    Text("Zones Active")
                    Spacer()
                    Text(profileStore.appState.zonesEnabled ? "On" : "Off")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Divider()

            // Profile switcher
            Menu("Profile: \(activeProfile.name)") {
                ForEach(profileStore.appState.profiles) { profile in
                    Button(action: {
                        profileStore.setActiveProfile(profile)
                        if zoneEngine.isActive {
                            zoneEngine.updateZones(profile.zones)
                            captureFrameManager.syncFrames(
                                zones: profile.zones,
                                screen: zoneEngine.targetScreen
                            )
                        }
                    }) {
                        HStack {
                            if profile.id == profileStore.appState.activeProfileId {
                                Image(systemName: "checkmark")
                            }
                            Text(profile.name)
                        }
                    }
                }
            }

            Divider()

            // Capture frame toggles
            if !activeProfile.zones.isEmpty {
                Text("Capture Frames")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                ForEach(activeProfile.zones) { zone in
                    Button(action: {
                        profileStore.toggleCaptureFrame(
                            zoneId: zone.id,
                            profileId: activeProfile.id
                        )
                        captureFrameManager.syncFrames(
                            zones: profileStore.activeProfile.zones,
                            screen: zoneEngine.targetScreen
                        )
                    }) {
                        HStack {
                            Image(systemName: zone.captureFrameEnabled ? "checkmark.square.fill" : "square")
                            Text(zone.name)
                            Spacer()
                            if zone.captureFrameEnabled {
                                Image(systemName: "video.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            Divider()

            // Settings
            Button("Configure Zones...") {
                onOpenSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Preferences...") {
                onOpenPreferences()
            }

            Divider()

            Button("Quit ZoneMaster") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
