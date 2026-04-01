import SwiftUI

/// App delegate handles bootstrapping all services on launch.
/// SwiftUI MenuBarExtra doesn't have a reliable onAppear, so we use
/// NSApplicationDelegate.applicationDidFinishLaunching instead.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let profileStore = ProfileStore()
    let zoneEngine = ZoneEngine()
    let shortcutService = ShortcutService()
    let captureFrameManager = CaptureFrameManager()

    private var accessibilityRetryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("ZoneMaster: Starting up...")

        // Auto-activate zones if they were enabled (default: true)
        if profileStore.appState.zonesEnabled {
            let profile = profileStore.activeProfile
            zoneEngine.activate(
                with: profile,
                stickyEdgesEnabled: profileStore.appState.stickyEdgesEnabled,
                stickyEdgeThreshold: profileStore.appState.stickyEdgeThreshold
            )

            // Sync capture frames for zones that have them enabled
            captureFrameManager.syncFrames(
                zones: profile.zones,
                screen: zoneEngine.targetScreen
            )

            print("ZoneMaster: Zones activated with profile '\(profile.name)' (\(profile.zones.count) zones)")
        }

        // Start global keyboard shortcuts
        connectShortcuts()
        shortcutService.startListening()
        print("ZoneMaster: Keyboard shortcuts registered")

        // Set up launch at login based on saved preference
        LaunchAtLoginService.setEnabled(profileStore.appState.launchAtLogin)

        // If accessibility isn't granted yet, poll until it is and then
        // start the enforcer. macOS doesn't notify apps when permissions change.
        if !AccessibilityService.isAccessibilityEnabled() {
            print("ZoneMaster: Waiting for Accessibility permissions...")
            accessibilityRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AccessibilityService.isAccessibilityEnabled() {
                    print("ZoneMaster: Accessibility permissions granted!")
                    timer.invalidate()
                    self.accessibilityRetryTimer = nil

                    // Start the enforcer now that we have permissions
                    let profile = self.profileStore.activeProfile
                    if self.profileStore.appState.zonesEnabled {
                        self.zoneEngine.startEnforcerIfNeeded(zones: profile.zones)
                    }

                    // Restart shortcut listener (CGEvent tap also needs accessibility)
                    self.shortcutService.stopListening()
                    self.shortcutService.startListening()
                }
            }
        }
    }

    /// Wire shortcut callbacks to zone engine and profile store actions
    private func connectShortcuts() {
        shortcutService.bindings = profileStore.shortcutBindings

        shortcutService.onMoveToNextZone = { [weak self] in
            guard let self, self.zoneEngine.isActive else { return }
            self.zoneEngine.moveFocusedWindowToNextZone(zones: self.profileStore.activeProfile.zones)
        }

        shortcutService.onMoveToPreviousZone = { [weak self] in
            guard let self, self.zoneEngine.isActive else { return }
            self.zoneEngine.moveFocusedWindowToPreviousZone(zones: self.profileStore.activeProfile.zones)
        }

        shortcutService.onMoveToZone = { [weak self] index in
            guard let self, self.zoneEngine.isActive else { return }
            let zones = self.profileStore.activeProfile.zones
            guard index < zones.count else { return }
            self.zoneEngine.moveFocusedWindow(to: zones[index])
        }

        shortcutService.onToggleZones = { [weak self] in
            guard let self else { return }
            self.profileStore.toggleZonesEnabled()
            if self.profileStore.appState.zonesEnabled {
                let profile = self.profileStore.activeProfile
                self.zoneEngine.activate(
                    with: profile,
                    stickyEdgesEnabled: self.profileStore.appState.stickyEdgesEnabled,
                    stickyEdgeThreshold: self.profileStore.appState.stickyEdgeThreshold
                )
                self.captureFrameManager.syncFrames(
                    zones: profile.zones,
                    screen: self.zoneEngine.targetScreen
                )
            } else {
                self.zoneEngine.deactivate()
                self.captureFrameManager.hideAll()
            }
        }

        shortcutService.onNextProfile = { [weak self] in
            guard let self else { return }
            self.profileStore.switchToNextProfile()
            let profile = self.profileStore.activeProfile
            if self.zoneEngine.isActive {
                self.zoneEngine.updateZones(profile.zones)
                self.captureFrameManager.syncFrames(
                    zones: profile.zones,
                    screen: self.zoneEngine.targetScreen
                )
            }
        }
    }
}

@main
struct ZoneMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var settingsWindow: NSWindow?
    @State private var preferencesWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                profileStore: appDelegate.profileStore,
                zoneEngine: appDelegate.zoneEngine,
                captureFrameManager: appDelegate.captureFrameManager,
                onOpenSettings: openSettings,
                onOpenPreferences: openPreferences
            )
        } label: {
            Image(systemName: "rectangle.split.3x1")
                .symbolRenderingMode(.hierarchical)
        }
    }

    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ZoneConfigurationView(
            profileStore: appDelegate.profileStore,
            zoneEngine: appDelegate.zoneEngine
        )

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ZoneMaster — Configure Zones"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 500))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }

    private func openPreferences() {
        if let window = preferencesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PreferencesView(
            shortcutService: appDelegate.shortcutService,
            zoneEngine: appDelegate.zoneEngine
        )

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ZoneMaster — Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.preferencesWindow = window
    }
}
