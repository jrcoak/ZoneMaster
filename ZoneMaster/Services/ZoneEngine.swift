import AppKit
import Combine

/// Central coordinator that ties together zone enforcement, window observation,
/// and divider overlays. Owned by the app and driven by ProfileStore changes.
final class ZoneEngine: ObservableObject {
    @Published var isActive: Bool = false

    private let enforcer: AccessibilityZoneEnforcer
    private var dividerOverlay: DividerOverlayWindow?
    private var cancellables = Set<AnyCancellable>()

    /// The screen zones are applied to (primary screen for v1)
    var targetScreen: NSScreen {
        NSScreen.main ?? NSScreen.screens.first!
    }

    init() {
        self.enforcer = AccessibilityZoneEnforcer()
    }

    /// Start zone enforcement with the given profile.
    /// Dividers and state are always activated. Window constraining requires
    /// Accessibility permissions — if not yet granted, the enforcer will start
    /// but AX calls will silently fail until permissions are granted and the
    /// app is restarted (or re-activated via the retry timer in AppDelegate).
    func activate(with profile: Profile, stickyEdgesEnabled: Bool, stickyEdgeThreshold: Double) {
        let hasAccess = AccessibilityService.isAccessibilityEnabled()
        if !hasAccess {
            // Prompt for permissions but don't bail — still show dividers
            _ = AccessibilityService.isAccessibilityEnabled(prompt: true)
            print("ZoneMaster: Accessibility not yet granted — dividers will show but window constraining won't work until permissions are granted")
        }

        enforcer.stickyEdgesEnabled = stickyEdgesEnabled
        enforcer.stickyEdgeThreshold = CGFloat(stickyEdgeThreshold)

        if hasAccess {
            enforcer.startEnforcing(zones: profile.zones, on: targetScreen)
        }

        if profile.showDividers {
            showDividers(for: profile.zones)
        }

        isActive = true
        print("ZoneMaster: Activated with \(profile.zones.count) zones (profile: \(profile.name), accessibility: \(hasAccess ? "granted" : "pending"))")
    }

    /// Stop all zone enforcement
    func deactivate() {
        enforcer.stopEnforcing()
        hideDividers()
        isActive = false
        print("ZoneMaster: Deactivated")
    }

    /// Update zones without restarting (e.g., after profile switch or zone edit)
    func updateZones(_ zones: [Zone]) {
        enforcer.updateZones(zones, on: targetScreen)
        if isActive {
            showDividers(for: zones)
        }
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

    /// Try to start the enforcer if accessibility was granted after initial activation.
    /// Called by the AppDelegate retry timer.
    func startEnforcerIfNeeded(zones: [Zone]) {
        guard isActive, AccessibilityService.isAccessibilityEnabled() else { return }
        enforcer.startEnforcing(zones: zones, on: targetScreen)
        print("ZoneMaster: Accessibility granted — enforcer started")
    }

    /// Whether the enforcer is actually running (has accessibility)
    var isEnforcerRunning: Bool {
        isActive && AccessibilityService.isAccessibilityEnabled()
    }

    /// Update sticky edge settings
    func updateStickyEdges(enabled: Bool, threshold: Double) {
        enforcer.stickyEdgesEnabled = enabled
        enforcer.stickyEdgeThreshold = CGFloat(threshold)
    }

    // MARK: - Divider Overlay

    func showDividers(for zones: [Zone]) {
        let screen = targetScreen
        if dividerOverlay == nil {
            dividerOverlay = DividerOverlayWindow(screen: screen)
        }
        dividerOverlay?.updateDividers(zones: zones, screen: screen)
        dividerOverlay?.showDividers()
    }

    func hideDividers() {
        dividerOverlay?.hideDividers()
    }
}
