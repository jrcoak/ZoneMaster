import SwiftUI

/// Preferences window — keyboard shortcuts, sticky edges, launch at login, divider style.
struct PreferencesView: View {
    @ObservedObject var shortcutService: ShortcutService
    @ObservedObject var zoneEngine: ZoneEngine

    @State private var launchAtLogin: Bool = LaunchAtLoginService.isEnabled
    @State private var stickyEdgesEnabled: Bool = true
    @State private var stickyEdgeThreshold: Double = 20.0
    @State private var bindings: ShortcutBindings = .makeDefault()

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            bindings = shortcutService.bindings
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch ZoneMaster at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginService.setEnabled(newValue)
                    }
            }

            Section("Sticky Edges") {
                Toggle("Enable sticky edges between zones", isOn: $stickyEdgesEnabled)
                    .onChange(of: stickyEdgesEnabled) { _, newValue in
                        zoneEngine.updateStickyEdges(enabled: newValue, threshold: stickyEdgeThreshold)
                    }

                if stickyEdgesEnabled {
                    HStack {
                        Text("Resistance:")
                        Slider(value: $stickyEdgeThreshold, in: 5...50, step: 5)
                            .onChange(of: stickyEdgeThreshold) { _, newValue in
                                zoneEngine.updateStickyEdges(enabled: stickyEdgesEnabled, threshold: newValue)
                            }
                        Text("\(Int(stickyEdgeThreshold))px")
                            .frame(width: 40)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Accessibility") {
                HStack {
                    if AccessibilityService.isAccessibilityEnabled() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility access granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility access required")
                        Spacer()
                        Button("Grant Access") {
                            _ = AccessibilityService.isAccessibilityEnabled(prompt: true)
                        }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("ZoneMaster")
                        .font(.headline)
                    Spacer()
                    Text("v1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Shortcuts Tab

    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.bottom, 4)

            Text("Click a shortcut field and press your desired key combination.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ShortcutRecorderView(label: "Move to next zone", shortcut: $bindings.moveToNextZone)
                    ShortcutRecorderView(label: "Move to previous zone", shortcut: $bindings.moveToPreviousZone)

                    Divider()
                        .padding(.vertical, 4)

                    ShortcutRecorderView(label: "Move to Zone 1", shortcut: $bindings.moveToZone1)
                    ShortcutRecorderView(label: "Move to Zone 2", shortcut: $bindings.moveToZone2)
                    ShortcutRecorderView(label: "Move to Zone 3", shortcut: $bindings.moveToZone3)
                    ShortcutRecorderView(label: "Move to Zone 4", shortcut: $bindings.moveToZone4)

                    Divider()
                        .padding(.vertical, 4)

                    ShortcutRecorderView(label: "Toggle zones on/off", shortcut: $bindings.toggleZones)
                    ShortcutRecorderView(label: "Next profile", shortcut: $bindings.nextProfile)
                }
            }

            Spacer()

            HStack {
                Button("Reset to Defaults") {
                    bindings = .makeDefault()
                    shortcutService.updateBindings(bindings)
                }

                Spacer()

                Button("Apply") {
                    shortcutService.updateBindings(bindings)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}
