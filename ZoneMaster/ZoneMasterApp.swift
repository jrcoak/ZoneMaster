import SwiftUI

@main
struct ZoneMasterApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var zoneEngine = ZoneEngine()
    @StateObject private var shortcutService = ShortcutService()
    @StateObject private var captureFrameManager = CaptureFrameManager()

    @State private var settingsWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                profileStore: profileStore,
                zoneEngine: zoneEngine,
                captureFrameManager: captureFrameManager,
                onOpenSettings: openSettings,
                onOpenPreferences: openPreferences
            )
        } label: {
            Image(systemName: "rectangle.split.3x1")
                .symbolRenderingMode(.hierarchical)
        }
    }

    private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ZoneConfigurationView(
            profileStore: profileStore,
            zoneEngine: zoneEngine
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
        let view = PreferencesView(
            shortcutService: shortcutService,
            zoneEngine: zoneEngine
        )

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ZoneMaster — Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
