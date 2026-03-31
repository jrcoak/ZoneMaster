import AppKit
import ApplicationServices

/// Protocol abstracting zone enforcement. Currently implemented via Accessibility APIs.
/// Designed to be swappable for a virtual display driver in the future.
protocol ZoneEnforcerProtocol {
    func startEnforcing(zones: [Zone], on screen: NSScreen)
    func stopEnforcing()
    func updateZones(_ zones: [Zone], on screen: NSScreen)
    func moveFocusedWindow(to zone: Zone, on screen: NSScreen)
}

/// Accessibility-based zone enforcer. Uses AXObserver to watch for window resize
/// events (which fire on maximize/zoom) and a lightweight poll for sticky edges.
///
/// Key coordinate distinction:
/// - `screen.visibleFrame` for window constraining (excludes menu bar + Dock)
/// - `screen.frame` for zone hit-testing and divider overlay (full screen)
final class AccessibilityZoneEnforcer: ZoneEnforcerProtocol {
    private var isEnforcing = false
    private var currentZones: [Zone] = []
    private var currentScreen: NSScreen?
    private var observers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?

    // Track last known window frames for maximize detection and sticky edges
    private var lastWindowFrames: [String: CGRect] = [:]

    var stickyEdgesEnabled: Bool = true
    var stickyEdgeThreshold: CGFloat = 20.0

    // MARK: - Public API

    func startEnforcing(zones: [Zone], on screen: NSScreen) {
        currentZones = zones
        currentScreen = screen
        isEnforcing = true

        // Observe all running apps for window resize/move events
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            observeApp(pid: app.processIdentifier)
        }

        // Watch for new app launches
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        // Poll at 200ms for sticky edges and as a fallback for missed events
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.pollForStickyEdges()
        }
    }

    func stopEnforcing() {
        isEnforcing = false
        pollTimer?.invalidate()
        pollTimer = nil
        observers.removeAll()
        lastWindowFrames.removeAll()

        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func updateZones(_ zones: [Zone], on screen: NSScreen) {
        currentZones = zones
        currentScreen = screen
    }

    func moveFocusedWindow(to zone: Zone, on screen: NSScreen) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AccessibilityService.applicationElement(pid: frontApp.processIdentifier)
        guard let window = AccessibilityService.getFocusedWindow(for: appElement) else { return }

        let targetRect = zoneVisibleRect(zone, on: screen)
        AccessibilityService.setWindowFrame(window, frame: targetRect)
    }

    // MARK: - AXObserver Setup

    @objc private func appLaunched(_ notification: Notification) {
        guard isEnforcing,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        observeApp(pid: app.processIdentifier)
    }

    private func observeApp(pid: pid_t) {
        // Skip our own app and already-observed apps
        guard pid != ProcessInfo.processInfo.processIdentifier,
              observers[pid] == nil else { return }

        // Pass self as refcon so the C callback can reach us
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        var observer: AXObserver?
        let result = AXObserverCreate(pid, axCallback, &observer)
        guard result == .success, let observer = observer else { return }

        let appElement = AccessibilityService.applicationElement(pid: pid)

        // Watch for window resize (fires on maximize/zoom), move, and creation
        for notif in [
            kAXWindowResizedNotification,
            kAXWindowMovedNotification,
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
        ] as [CFString] {
            AXObserverAddNotification(observer, appElement, notif, refcon)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers[pid] = observer
    }

    // MARK: - AX Callback

    /// Called by the AXObserver when a window event fires.
    /// This is a C function pointer — uses refcon to get back to the enforcer instance.
    private static let axCallback: AXObserverCallback = { _, element, notification, refcon in
        guard let refcon = refcon else { return }
        let enforcer = Unmanaged<AccessibilityZoneEnforcer>.fromOpaque(refcon).takeUnretainedValue()
        let notifString = notification as String

        if notifString == kAXWindowResizedNotification as String {
            enforcer.handleWindowResized(element)
        }
    }

    /// When a window is resized, check if it just maximized (filled the visible screen).
    /// If so, constrain it to the zone it was in before the resize.
    private func handleWindowResized(_ window: AXUIElement) {
        guard isEnforcing, let screen = currentScreen else { return }

        guard !AccessibilityService.isWindowFullScreen(window),
              !AccessibilityService.isWindowMinimized(window) else { return }

        guard let currentFrame = AccessibilityService.getWindowFrame(window) else { return }

        let visibleFrame = screen.visibleFrame
        let windowKey = windowIdentifier(window)
        let previousFrame = lastWindowFrames[windowKey]

        // Check if the window now fills the visible screen (maximize/zoom happened)
        let fillsWidth = abs(currentFrame.width - visibleFrame.width) < 20
        let fillsHeight = abs(currentFrame.height - visibleFrame.height) < 20
        let isMaximized = fillsWidth && fillsHeight

        if isMaximized {
            // Find which zone the window was in before maximizing
            let referenceFrame = previousFrame ?? currentFrame
            if let zone = findContainingZone(for: referenceFrame, on: screen) {
                let zoneRect = zoneVisibleRect(zone, on: screen)

                // Only constrain if the zone is smaller than the full screen
                // (i.e., there are actually multiple zones)
                if currentZones.count > 1 {
                    // Small delay to let the system animation finish, then override
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        AccessibilityService.setWindowFrame(window, frame: zoneRect)
                        self.lastWindowFrames[windowKey] = zoneRect
                    }
                    return
                }
            }
        }

        lastWindowFrames[windowKey] = currentFrame
    }

    // MARK: - Sticky Edges (Poll-based)

    /// Lightweight poll for sticky edge enforcement.
    /// Only processes the frontmost app's focused window to minimize overhead.
    private func pollForStickyEdges() {
        guard isEnforcing, stickyEdgesEnabled, let screen = currentScreen else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }

        let appElement = AccessibilityService.applicationElement(pid: frontApp.processIdentifier)
        guard let window = AccessibilityService.getFocusedWindow(for: appElement),
              let currentFrame = AccessibilityService.getWindowFrame(window) else { return }

        let windowKey = windowIdentifier(window)
        guard let previousFrame = lastWindowFrames[windowKey] else {
            lastWindowFrames[windowKey] = currentFrame
            return
        }

        // Only apply when dragging (position changed, size didn't)
        let sizeChanged = abs(currentFrame.width - previousFrame.width) > 2 ||
                          abs(currentFrame.height - previousFrame.height) > 2
        guard !sizeChanged else {
            lastWindowFrames[windowKey] = currentFrame
            return
        }

        // Check if crossing a zone boundary
        let prevZone = findContainingZone(for: previousFrame, on: screen)
        let currZone = findContainingZone(for: currentFrame, on: screen)

        if prevZone?.id != currZone?.id, let prevZone = prevZone {
            let prevZoneRect = zoneVisibleRect(prevZone, on: screen)

            if let adjusted = stickyEdgeAdjustment(
                previous: previousFrame,
                current: currentFrame,
                zoneBounds: prevZoneRect
            ) {
                AccessibilityService.setWindowPosition(window, position: adjusted.origin)
                lastWindowFrames[windowKey] = adjusted
                return
            }
        }

        lastWindowFrames[windowKey] = currentFrame
    }

    // MARK: - Zone Geometry

    /// Convert a zone's normalized rect to screen coordinates using visibleFrame.
    /// This ensures windows don't overlap the menu bar or Dock.
    private func zoneVisibleRect(_ zone: Zone, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.origin.x + zone.normalizedRect.x * visible.width,
            y: visible.origin.y + zone.normalizedRect.y * visible.height,
            width: zone.normalizedRect.width * visible.width,
            height: zone.normalizedRect.height * visible.height
        )
    }

    /// Find which zone contains the center of a window frame.
    /// Uses full screen frame for hit-testing (zones tile the full screen).
    private func findContainingZone(for windowFrame: CGRect, on screen: NSScreen) -> Zone? {
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return currentZones.first { zone in
            zone.screenRect(for: screen.frame).contains(windowCenter)
        }
    }

    // MARK: - Sticky Edge Math

    private func stickyEdgeAdjustment(previous: CGRect, current: CGRect, zoneBounds: CGRect) -> CGRect? {
        let dx = current.origin.x - previous.origin.x
        let dy = current.origin.y - previous.origin.y

        // Right edge
        if dx > 0 && current.maxX > zoneBounds.maxX && current.maxX - zoneBounds.maxX < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.x = zoneBounds.maxX - current.width
            return adjusted
        }
        // Left edge
        if dx < 0 && current.origin.x < zoneBounds.origin.x && zoneBounds.origin.x - current.origin.x < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.x = zoneBounds.origin.x
            return adjusted
        }
        // Bottom edge (macOS: lower y = bottom)
        if dy < 0 && current.origin.y < zoneBounds.origin.y && zoneBounds.origin.y - current.origin.y < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.y = zoneBounds.origin.y
            return adjusted
        }
        // Top edge
        if dy > 0 && current.maxY > zoneBounds.maxY && current.maxY - zoneBounds.maxY < stickyEdgeThreshold {
            var adjusted = current
            adjusted.origin.y = zoneBounds.maxY - current.height
            return adjusted
        }

        return nil
    }

    // MARK: - Window Identity

    /// Generate a stable identifier for a window using its memory address.
    /// More reliable than title-based identification.
    private func windowIdentifier(_ window: AXUIElement) -> String {
        let ptr = Unmanaged.passUnretained(window).toOpaque()
        return "\(ptr)"
    }
}
