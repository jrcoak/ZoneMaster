import AppKit
import ApplicationServices

/// Observes system-wide window events and delegates to the zone enforcer.
/// Separated from ZoneEnforcer to keep observation logic independent of enforcement strategy.
final class WindowObserver {
    private var workspaceObservers: [NSObjectProtocol] = []

    /// Called when a new window is created in any app
    var onWindowCreated: ((AXUIElement, pid_t) -> Void)?

    /// Called when the focused window changes
    var onFocusedWindowChanged: ((AXUIElement, pid_t) -> Void)?

    func startObserving() {
        // Watch for app launches to set up per-app observers
        let launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.setupAppObserver(for: app)
        }
        workspaceObservers.append(launchObserver)

        // Watch for app terminations to clean up
        let terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Cleanup happens naturally as AXObservers are invalidated
        }
        workspaceObservers.append(terminateObserver)

        // Set up observers for already-running apps
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            setupAppObserver(for: app)
        }
    }

    func stopObserving() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func setupAppObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }

        // Best-effort: some apps don't support AX observation
        guard let observer = AccessibilityService.createObserver(pid: pid, callback: { _, element, notification, _ in
            let notifString = notification as String
            if notifString == kAXWindowCreatedNotification as String {
                // New window created — could constrain to active zone
            }
        }) else { return }

        let appElement = AccessibilityService.applicationElement(pid: pid)
        AccessibilityService.addNotification(observer, element: appElement, notification: kAXWindowCreatedNotification as CFString)
        AccessibilityService.scheduleObserver(observer)
    }
}
