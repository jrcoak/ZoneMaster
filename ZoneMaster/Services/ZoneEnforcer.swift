import AppKit
import ApplicationServices

/// Protocol abstracting zone enforcement.
protocol ZoneEnforcerProtocol {
    func startEnforcing(zones: [Zone], on screen: NSScreen)
    func stopEnforcing()
    func updateZones(_ zones: [Zone], on screen: NSScreen)
    func moveFocusedWindow(to zone: Zone, on screen: NSScreen)
}

// MARK: - Free function for AXObserver C callback
// Must be a top-level function (not a closure or method) to be used as a C function pointer.
private func zoneEnforcerAXCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let enforcer = Unmanaged<AccessibilityZoneEnforcer>.fromOpaque(refcon).takeUnretainedValue()
    enforcer.handleAXNotification(element: element, notification: notification as String)
}

/// Accessibility-based zone enforcer. Polls all windows to detect maximize events
/// and enforce sticky edges. Uses a simple, reliable polling approach rather than
/// AXObserver (which has issues with C function pointer bridging and unstable
/// AXUIElement references).
final class AccessibilityZoneEnforcer: ZoneEnforcerProtocol {
    private var isEnforcing = false
    private var currentZones: [Zone] = []
    private var currentScreen: NSScreen?
    private var pollTimer: Timer?
    private var observers: [pid_t: AXObserver] = [:]

    // Track window frames by PID + window title (stable across AX calls)
    private var lastWindowFrames: [String: CGRect] = [:]

    var stickyEdgesEnabled: Bool = true
    var stickyEdgeThreshold: CGFloat = 20.0

    // MARK: - Public API

    func startEnforcing(zones: [Zone], on screen: NSScreen) {
        currentZones = zones
        currentScreen = screen
        isEnforcing = true

        print("ZoneMaster: Enforcer starting with \(zones.count) zones")

        // Set up AX observers for all running apps
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

        // Also poll as a fallback — catches anything the observers miss
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.pollAllWindows()
        }

        print("ZoneMaster: Enforcer started, observing \(observers.count) apps")
    }

    func stopEnforcing() {
        isEnforcing = false
        pollTimer?.invalidate()
        pollTimer = nil
        observers.removeAll()
        lastWindowFrames.removeAll()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        print("ZoneMaster: Enforcer stopped")
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

    // MARK: - AXObserver

    @objc private func appLaunched(_ notification: Notification) {
        guard isEnforcing,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        observeApp(pid: app.processIdentifier)
    }

    private func observeApp(pid: pid_t) {
        guard pid != ProcessInfo.processInfo.processIdentifier,
              observers[pid] == nil else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        var observer: AXObserver?
        let result = AXObserverCreate(pid, zoneEnforcerAXCallback, &observer)
        guard result == .success, let observer = observer else { return }

        let appElement = AccessibilityService.applicationElement(pid: pid)

        for notif in [
            kAXWindowResizedNotification,
            kAXWindowMovedNotification,
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

    /// Called from the free function AX callback
    func handleAXNotification(element: AXUIElement, notification: String) {
        guard isEnforcing else { return }

        if notification == kAXWindowResizedNotification as String {
            checkAndConstrainWindow(element)
        }
    }

    // MARK: - Window Polling & Constraining

    /// Poll all visible windows. Detects maximize and applies sticky edges.
    private func pollAllWindows() {
        guard isEnforcing, let screen = currentScreen else { return }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { continue }

            let appElement = AccessibilityService.applicationElement(pid: app.processIdentifier)
            let windows = AccessibilityService.getWindows(for: appElement)

            for window in windows {
                guard !AccessibilityService.isWindowMinimized(window),
                      !AccessibilityService.isWindowFullScreen(window) else { continue }

                guard let currentFrame = AccessibilityService.getWindowFrame(window) else { continue }

                let windowKey = stableWindowKey(window, pid: app.processIdentifier)
                let previousFrame = lastWindowFrames[windowKey]

                // Detect maximize: window fills the visible screen
                if didJustMaximize(previous: previousFrame, current: currentFrame, screen: screen) {
                    constrainToZone(window: window, windowKey: windowKey, previousFrame: previousFrame, currentFrame: currentFrame, screen: screen)
                    continue
                }

                // Sticky edges
                if stickyEdgesEnabled, let prev = previousFrame {
                    if applyStickyEdge(window: window, windowKey: windowKey, previous: prev, current: currentFrame, screen: screen) {
                        continue
                    }
                }

                lastWindowFrames[windowKey] = currentFrame
            }
        }
    }

    /// Called from AX observer when a window is resized
    private func checkAndConstrainWindow(_ window: AXUIElement) {
        guard isEnforcing, let screen = currentScreen else { return }
        guard !AccessibilityService.isWindowFullScreen(window),
              !AccessibilityService.isWindowMinimized(window) else { return }
        guard let currentFrame = AccessibilityService.getWindowFrame(window) else { return }

        // Try to find PID for this window's app
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let windowKey = stableWindowKey(window, pid: pid)
        let previousFrame = lastWindowFrames[windowKey]

        if didJustMaximize(previous: previousFrame, current: currentFrame, screen: screen) {
            constrainToZone(window: window, windowKey: windowKey, previousFrame: previousFrame, currentFrame: currentFrame, screen: screen)
        } else {
            lastWindowFrames[windowKey] = currentFrame
        }
    }

    // MARK: - Maximize Detection

    private func didJustMaximize(previous: CGRect?, current: CGRect, screen: NSScreen) -> Bool {
        let visible = screen.visibleFrame

        // Does the window now fill the visible screen?
        let fillsWidth = abs(current.width - visible.width) < 30
        let fillsHeight = abs(current.height - visible.height) < 30
        guard fillsWidth && fillsHeight else { return false }

        // If we have a previous frame, was it smaller?
        if let prev = previous {
            let wasSmaller = prev.width < visible.width * 0.85 || prev.height < visible.height * 0.85
            return wasSmaller
        }

        // No previous frame — still treat as maximize if it fills the screen
        // (first time seeing this window and it's already maximized)
        return true
    }

    private func constrainToZone(window: AXUIElement, windowKey: String, previousFrame: CGRect?, currentFrame: CGRect, screen: NSScreen) {
        guard currentZones.count > 1 else {
            lastWindowFrames[windowKey] = currentFrame
            return
        }

        // Use previous position to determine which zone, or current if no previous
        let referenceFrame = previousFrame ?? currentFrame
        guard let zone = findContainingZone(for: referenceFrame, on: screen) else {
            lastWindowFrames[windowKey] = currentFrame
            return
        }

        let zoneRect = zoneVisibleRect(zone, on: screen)

        print("ZoneMaster: Constraining window to \(zone.name) — \(zoneRect)")

        // Delay slightly to let macOS finish its animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            AccessibilityService.setWindowFrame(window, frame: zoneRect)
            self?.lastWindowFrames[windowKey] = zoneRect
        }
    }

    // MARK: - Sticky Edges

    private func applyStickyEdge(window: AXUIElement, windowKey: String, previous: CGRect, current: CGRect, screen: NSScreen) -> Bool {
        // Only when dragging (position changed, size didn't)
        let sizeChanged = abs(current.width - previous.width) > 2 || abs(current.height - previous.height) > 2
        guard !sizeChanged else { return false }

        let prevZone = findContainingZone(for: previous, on: screen)
        let currZone = findContainingZone(for: current, on: screen)

        guard prevZone?.id != currZone?.id, let prevZone = prevZone else { return false }

        let prevZoneRect = zoneVisibleRect(prevZone, on: screen)
        let dx = current.origin.x - previous.origin.x
        let dy = current.origin.y - previous.origin.y

        var adjusted: CGRect?

        if dx > 0 && current.maxX > prevZoneRect.maxX && current.maxX - prevZoneRect.maxX < stickyEdgeThreshold {
            adjusted = current; adjusted!.origin.x = prevZoneRect.maxX - current.width
        } else if dx < 0 && current.origin.x < prevZoneRect.origin.x && prevZoneRect.origin.x - current.origin.x < stickyEdgeThreshold {
            adjusted = current; adjusted!.origin.x = prevZoneRect.origin.x
        } else if dy < 0 && current.origin.y < prevZoneRect.origin.y && prevZoneRect.origin.y - current.origin.y < stickyEdgeThreshold {
            adjusted = current; adjusted!.origin.y = prevZoneRect.origin.y
        } else if dy > 0 && current.maxY > prevZoneRect.maxY && current.maxY - prevZoneRect.maxY < stickyEdgeThreshold {
            adjusted = current; adjusted!.origin.y = prevZoneRect.maxY - current.height
        }

        if let adjusted = adjusted {
            AccessibilityService.setWindowPosition(window, position: adjusted.origin)
            lastWindowFrames[windowKey] = adjusted
            return true
        }

        return false
    }

    // MARK: - Zone Geometry

    /// Zone rect in visibleFrame coordinates (for window placement)
    private func zoneVisibleRect(_ zone: Zone, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.origin.x + zone.normalizedRect.x * visible.width,
            y: visible.origin.y + zone.normalizedRect.y * visible.height,
            width: zone.normalizedRect.width * visible.width,
            height: zone.normalizedRect.height * visible.height
        )
    }

    /// Find which zone contains the center of a window.
    /// Uses visibleFrame-based zone rects so coordinates match window positions.
    private func findContainingZone(for windowFrame: CGRect, on screen: NSScreen) -> Zone? {
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return currentZones.first { zone in
            zoneVisibleRect(zone, on: screen).contains(windowCenter)
        }
    }

    // MARK: - Window Identity

    /// Stable window identifier using PID + title.
    /// AXUIElement pointers are NOT stable across calls — each AX query
    /// returns a new object. PID + title is imperfect but reliable enough.
    private func stableWindowKey(_ window: AXUIElement, pid: pid_t) -> String {
        let title = AccessibilityService.getWindowTitle(window) ?? "untitled"
        return "\(pid)|\(title)"
    }
}
