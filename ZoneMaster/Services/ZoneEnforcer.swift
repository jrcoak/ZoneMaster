import AppKit
import ApplicationServices

/// Protocol abstracting zone enforcement. Currently implemented via Accessibility APIs.
/// Designed to be swappable for a virtual display driver in the future.
protocol ZoneEnforcerProtocol {
    /// Start enforcing zones on the given screen
    func startEnforcing(zones: [Zone], on screen: NSScreen)
    /// Stop all enforcement
    func stopEnforcing()
    /// Update the active zone layout without restarting
    func updateZones(_ zones: [Zone], on screen: NSScreen)
    /// Move the focused window to a specific zone
    func moveFocusedWindow(to zone: Zone, on screen: NSScreen)
    /// Constrain a window to the zone it's currently in (used on maximize)
    func constrainToCurrentZone(window: AXUIElement, zones: [Zone], on screen: NSScreen)
}

/// Accessibility-based zone enforcer. Monitors window events and constrains
/// windows to their containing zone.
final class AccessibilityZoneEnforcer: ZoneEnforcerProtocol {
    private var isEnforcing = false
    private var currentZones: [Zone] = []
    private var currentScreen: NSScreen?
    private var observers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?

    // Track last known window positions for sticky edge detection
    private var lastWindowPositions: [String: CGRect] = [:]

    var stickyEdgesEnabled: Bool = true
    var stickyEdgeThreshold: CGFloat = 20.0

    func startEnforcing(zones: [Zone], on screen: NSScreen) {
        currentZones = zones
        currentScreen = screen
        isEnforcing = true

        // Poll for window changes every 100ms
        // AXObserver is used for focused app, polling catches the rest
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollWindowStates()
        }

        observeFrontmostApp()

        // Register for app activation changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func stopEnforcing() {
        isEnforcing = false
        pollTimer?.invalidate()
        pollTimer = nil
        observers.removeAll()
        lastWindowPositions.removeAll()

        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func updateZones(_ zones: [Zone], on screen: NSScreen) {
        currentZones = zones
        currentScreen = screen
    }

    func moveFocusedWindow(to zone: Zone, on screen: NSScreen) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AccessibilityService.applicationElement(pid: frontApp.processIdentifier)
        guard let window = AccessibilityService.getFocusedWindow(for: appElement) else { return }

        let targetRect = zone.screenRect(for: screen.frame)
        AccessibilityService.setWindowFrame(window, frame: targetRect)
    }

    func constrainToCurrentZone(window: AXUIElement, zones: [Zone], on screen: NSScreen) {
        guard let windowFrame = AccessibilityService.getWindowFrame(window) else { return }
        guard let zone = findContainingZone(for: windowFrame, zones: zones, screen: screen) else { return }

        let zoneRect = zone.screenRect(for: screen.frame)
        AccessibilityService.setWindowFrame(window, frame: zoneRect)
    }

    // MARK: - Private

    @objc private func frontmostAppChanged(_ notification: Notification) {
        guard isEnforcing else { return }
        observeFrontmostApp()
    }

    private func observeFrontmostApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier

        // Skip if already observing this app
        guard observers[pid] == nil else { return }

        // Skip our own app
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }

        guard let observer = AccessibilityService.createObserver(pid: pid, callback: { observer, element, notification, refcon in
            // Window moved or resized — handled by polling for simplicity
            // The observer is primarily used to detect maximize events
        }) else { return }

        let appElement = AccessibilityService.applicationElement(pid: pid)

        // Watch for window creation and focus changes
        AccessibilityService.addNotification(observer, element: appElement, notification: kAXWindowCreatedNotification as CFString)
        AccessibilityService.addNotification(observer, element: appElement, notification: kAXFocusedWindowChangedNotification as CFString)
        AccessibilityService.scheduleObserver(observer)

        observers[pid] = observer
    }

    private func pollWindowStates() {
        guard isEnforcing, let screen = currentScreen else { return }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            // Skip our own app
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { continue }

            let appElement = AccessibilityService.applicationElement(pid: app.processIdentifier)
            let windows = AccessibilityService.getWindows(for: appElement)

            for window in windows {
                guard !AccessibilityService.isWindowMinimized(window),
                      !AccessibilityService.isWindowFullScreen(window),
                      let subrole = AccessibilityService.getWindowSubrole(window),
                      subrole == "AXStandardWindow" else { continue }

                guard let currentFrame = AccessibilityService.getWindowFrame(window) else { continue }

                let windowKey = windowIdentifier(window, pid: app.processIdentifier)
                let previousFrame = lastWindowPositions[windowKey]

                // Detect maximize: window suddenly fills the screen
                if let prev = previousFrame, didWindowMaximize(previous: prev, current: currentFrame, screen: screen) {
                    // Constrain to the zone the window was in before maximizing
                    if let zone = findContainingZone(for: prev, zones: currentZones, screen: screen) {
                        let zoneRect = zone.screenRect(for: screen.frame)
                        AccessibilityService.setWindowFrame(window, frame: zoneRect)
                        lastWindowPositions[windowKey] = zoneRect
                        continue
                    }
                }

                // Apply sticky edges if enabled
                if stickyEdgesEnabled, let prev = previousFrame {
                    if let adjusted = applyStickyEdges(previous: prev, current: currentFrame, screen: screen) {
                        AccessibilityService.setWindowPosition(window, position: adjusted.origin)
                        lastWindowPositions[windowKey] = adjusted
                        continue
                    }
                }

                lastWindowPositions[windowKey] = currentFrame
            }
        }
    }

    /// Detect if a window just maximized (jumped from a smaller size to filling the screen)
    private func didWindowMaximize(previous: CGRect, current: CGRect, screen: NSScreen) -> Bool {
        let screenFrame = screen.visibleFrame
        let fillsScreen = abs(current.width - screenFrame.width) < 10 &&
                          abs(current.height - screenFrame.height) < 10
        let wasSmaller = previous.width < screenFrame.width * 0.9 ||
                        previous.height < screenFrame.height * 0.9
        return fillsScreen && wasSmaller
    }

    /// Find which zone a window center falls within
    private func findContainingZone(for windowFrame: CGRect, zones: [Zone], screen: NSScreen) -> Zone? {
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return zones.first { zone in
            zone.screenRect(for: screen.frame).contains(windowCenter)
        }
    }

    /// Apply sticky edge resistance when a window is dragged near a zone boundary.
    /// Returns an adjusted frame if the window should be "stuck", nil otherwise.
    private func applyStickyEdges(previous: CGRect, current: CGRect, screen: NSScreen) -> CGRect? {
        // Only apply when the window is being dragged (position changed, size didn't)
        let sizeChanged = abs(current.width - previous.width) > 2 || abs(current.height - previous.height) > 2
        guard !sizeChanged else { return nil }

        let prevZone = findContainingZone(for: previous, zones: currentZones, screen: screen)
        let currZone = findContainingZone(for: current, zones: currentZones, screen: screen)

        // Only apply sticky edges when crossing a zone boundary
        guard prevZone?.id != currZone?.id, let prevZone = prevZone else { return nil }

        let prevZoneRect = prevZone.screenRect(for: screen.frame)

        // Check if the drag distance past the boundary is within the threshold
        let dx = current.origin.x - previous.origin.x
        let dy = current.origin.y - previous.origin.y

        // Check right edge
        if dx > 0 && current.maxX > prevZoneRect.maxX && current.maxX - prevZoneRect.maxX < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.x = prevZoneRect.maxX - current.width
            return adjusted
        }
        // Check left edge
        if dx < 0 && current.origin.x < prevZoneRect.origin.x && prevZoneRect.origin.x - current.origin.x < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.x = prevZoneRect.origin.x
            return adjusted
        }
        // Check bottom edge
        if dy > 0 && current.maxY > prevZoneRect.maxY && current.maxY - prevZoneRect.maxY < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.y = prevZoneRect.maxY - current.height
            return adjusted
        }
        // Check top edge
        if dy < 0 && current.origin.y < prevZoneRect.origin.y && prevZoneRect.origin.y - current.origin.y < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.y = prevZoneRect.origin.y
            return adjusted
        }

        return nil
    }

    /// Generate a stable identifier for a window
    private func windowIdentifier(_ window: AXUIElement, pid: pid_t) -> String {
        let title = AccessibilityService.getWindowTitle(window) ?? "untitled"
        // Use PID + title as a rough identifier. Not perfect but sufficient for tracking.
        return "\(pid)_\(title)"
    }
}
