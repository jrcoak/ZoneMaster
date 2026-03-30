import AppKit
import Combine

/// Central coordinator that ties together zone enforcement, window observation,
/// capture frames, and divider overlays. Owned by the app and driven by ProfileStore changes.
final class ZoneEngine: ObservableObject {
    @Published var isActive: Bool = false

    private let enforcer: AccessibilityZoneEnforcer
    private let windowObserver: WindowObserver
    private var cancellables = Set<AnyCancellable>()

    /// The screen zones are applied to (primary screen for v1)
    var targetScreen: NSScreen {
        NSScreen.main ?? NSScreen.screens.first!
    }

    init() {
        self.enforcer = AccessibilityZoneEnforcer()
        self.windowObserver = WindowObserver()
    }

    /// Start zone enforcement with the given profile
    func activate(with profile: Profile, stickyEdgesEnabled: Bool, stickyEdgeThreshold: Double) {
        guard AccessibilityService.isAccessibilityEnabled() else {
            // Prompt for permissions
            _ = AccessibilityService.isAccessibilityEnabled(prompt: true)
            return
        }

        enforcer.stickyEdgesEnabled = stickyEdgesEnabled
        enforcer.stickyEdgeThreshold = CGFloat(stickyEdgeThreshold)
        enforcer.startEnforcing(zones: profile.zones, on: targetScreen)
        windowObserver.startObserving()
        isActive = true
    }

    /// Stop all zone enforcement
    func deactivate() {
        enforcer.stopEnforcing()
        windowObserver.stopObserving()
        isActive = false
    }

    /// Update zones without restarting (e.g., after profile switch or zone edit)
    func updateZones(_ zones: [Zone]) {
        enforcer.updateZones(zones, on: targetScreen)
    }

    /// Move the currently focused window to a specific zone
    func moveFocusedWindow(to zone: Zone) {
        enforcer.moveFocusedWindow(to: zone, on: targetScreen)
    }

    /// Move focused window to the next zone in the list
    func moveFocusedWindowToNextZone(zones: [Zone]) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AccessibilityService.applicationElement(pid: frontApp.processIdentifier)
        guard let window = AccessibilityService.getFocusedWindow(for: appElement),
              let windowFrame = AccessibilityService.getWindowFrame(window) else { return }

        let screen = targetScreen
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)

        // Find current zone
        let currentIndex = zones.firstIndex { zone in
            zone.screenRect(for: screen.frame).contains(windowCenter)
        } ?? 0

        let nextIndex = (currentIndex + 1) % zones.count
        moveFocusedWindow(to: zones[nextIndex])
    }

    /// Move focused window to the previous zone in the list
    func moveFocusedWindowToPreviousZone(zones: [Zone]) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AccessibilityService.applicationElement(pid: frontApp.processIdentifier)
        guard let window = AccessibilityService.getFocusedWindow(for: appElement),
              let windowFrame = AccessibilityService.getWindowFrame(window) else { return }

        let screen = targetScreen
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)

        let currentIndex = zones.firstIndex { zone in
            zone.screenRect(for: screen.frame).contains(windowCenter)
        } ?? 0

        let prevIndex = currentIndex == 0 ? zones.count - 1 : currentIndex - 1
        moveFocusedWindow(to: zones[prevIndex])
    }

    /// Update sticky edge settings
    func updateStickyEdges(enabled: Bool, threshold: Double) {
        enforcer.stickyEdgesEnabled = enabled
        enforcer.stickyEdgeThreshold = CGFloat(threshold)
    }
}
