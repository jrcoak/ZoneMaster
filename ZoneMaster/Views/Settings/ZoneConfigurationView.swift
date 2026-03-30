import SwiftUI

/// Main settings window for configuring zone layouts.
/// Combines preset picker, custom editor, and profile management.
struct ZoneConfigurationView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var zoneEngine: ZoneEngine

    @State private var selectedTab: ConfigTab = .layout
    @State private var editingZones: [Zone] = []

    enum ConfigTab: String, CaseIterable {
        case layout = "Layout"
        case profiles = "Profiles"
    }

    private var activeProfile: Profile {
        profileStore.activeProfile
    }

    private var selectedPreset: ZonePreset? {
        if case .preset(let preset) = activeProfile.layoutSource {
            return preset
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(ConfigTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Profile: \(activeProfile.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 12)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()
                .padding(.top, 4)

            // Content
            switch selectedTab {
            case .layout:
                layoutTab
            case .profiles:
                ProfileEditorView(profileStore: profileStore, zoneEngine: zoneEngine)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            editingZones = activeProfile.zones
        }
    }

    private var layoutTab: some View {
        VStack(spacing: 16) {
            // Preset picker
            GroupBox("Presets") {
                PresetPickerView(
                    selectedPreset: selectedPreset,
                    onSelect: { preset in
                        let zones = preset.generateZones()
                        editingZones = zones
                        profileStore.updateZones(zones, for: activeProfile.id)
                        profileStore.setLayoutSource(.preset(preset), for: activeProfile.id)
                        if zoneEngine.isActive {
                            zoneEngine.updateZones(zones)
                        }
                    }
                )
                .padding(8)
            }

            // Custom editor
            GroupBox("Custom Layout") {
                CustomZoneEditorView(
                    zones: $editingZones,
                    onZonesChanged: { zones in
                        profileStore.updateZones(zones, for: activeProfile.id)
                        profileStore.setLayoutSource(.custom, for: activeProfile.id)
                        if zoneEngine.isActive {
                            zoneEngine.updateZones(zones)
                        }
                    }
                )
                .padding(8)
            }

            Spacer()
        }
        .padding(16)
    }
}
