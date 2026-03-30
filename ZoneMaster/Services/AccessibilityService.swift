import AppKit
import ApplicationServices

/// Wraps macOS Accessibility APIs for reading and writing window properties.
/// All AX calls require the user to have granted Accessibility permissions.
final class AccessibilityService {

    // MARK: - Permission Check

    /// Returns true if the app has Accessibility permissions.
    /// Pass `prompt: true` on first launch to trigger the system dialog.
    static func isAccessibilityEnabled(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Window Properties

    /// Get the position of a window
    static func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    /// Get the size of a window
    static func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    /// Get the frame (position + size) of a window
    static func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = getWindowPosition(window),
              let size = getWindowSize(window) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Set the position of a window
    static func setWindowPosition(_ window: AXUIElement, position: CGPoint) {
        var point = position
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    /// Set the size of a window
    static func setWindowSize(_ window: AXUIElement, size: CGSize) {
        var sz = size
        guard let value = AXValueCreate(.cgSize, &sz) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    /// Set both position and size of a window
    static func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        setWindowPosition(window, position: frame.origin)
        setWindowSize(window, size: frame.size)
    }

    /// Get the title of a window
    static func getWindowTitle(_ window: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    /// Check if a window is minimized
    static func isWindowMinimized(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value)
        guard result == .success else { return false }
        return (value as? Bool) ?? false
    }

    /// Check if a window is in native full screen
    static func isWindowFullScreen(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value)
        guard result == .success else { return false }
        return (value as? Bool) ?? false
    }

    /// Get the subrole of a window (e.g., AXStandardWindow, AXDialog)
    static func getWindowSubrole(_ window: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    // MARK: - Application Windows

    /// Get the AXUIElement for an application by PID
    static func applicationElement(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// Get all windows of an application
    static func getWindows(for app: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    /// Get the focused window of an application
    static func getFocusedWindow(for app: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success else { return nil }
        return (value as! AXUIElement)
    }

    // MARK: - Observer

    /// Create an AXObserver for a given PID
    static func createObserver(pid: pid_t, callback: @escaping AXObserverCallback) -> AXObserver? {
        var observer: AXObserver?
        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success else { return nil }
        return observer
    }

    /// Add a notification to an observer
    static func addNotification(_ observer: AXObserver, element: AXUIElement, notification: CFString) {
        AXObserverAddNotification(observer, element, notification, nil)
    }

    /// Schedule an observer on the current run loop
    static func scheduleObserver(_ observer: AXObserver) {
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }
}
