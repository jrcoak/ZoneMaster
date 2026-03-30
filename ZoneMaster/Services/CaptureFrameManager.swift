import AppKit
import Combine

/// Manages the lifecycle of capture frame windows.
/// Creates, shows, hides, and repositions capture frames based on zone configuration.
/// Capture frame enabled/disabled state is persisted per zone per profile via ProfileStore.
final class CaptureFrameManager: ObservableObject {
    @Published private(set) var activeFrames: [UUID: CaptureFrameWindow] = [:]

    /// Show or update capture frames for the given zones on the given screen.
    /// Only creates frames for zones where `captureFrameEnabled` is true.
    func syncFrames(zones: [Zone], screen: NSScreen) {
        let screenFrame = screen.frame

        // Determine which zones should have frames
        let enabledZoneIds = Set(zones.filter(\.captureFrameEnabled).map(\.id))

        // Remove frames for zones that are no longer enabled
        for (zoneId, window) in activeFrames {
            if !enabledZoneIds.contains(zoneId) {
                window.orderOut(nil)
                activeFrames.removeValue(forKey: zoneId)
            }
        }

        // Create or update frames for enabled zones
        for zone in zones where zone.captureFrameEnabled {
            let zoneRect = zone.screenRect(for: screenFrame)

            if let existingWindow = activeFrames[zone.id] {
                existingWindow.updateFrame(to: zoneRect)
                if !existingWindow.isVisible {
                    existingWindow.orderFront(nil)
                }
            } else {
                let window = CaptureFrameWindow(
                    zoneId: zone.id,
                    zoneName: zone.name,
                    frame: zoneRect
                )
                window.orderFront(nil)
                activeFrames[zone.id] = window
            }
        }
    }

    /// Hide all capture frames (e.g., when zones are toggled off)
    func hideAll() {
        for (_, window) in activeFrames {
            window.orderOut(nil)
        }
    }

    /// Show all capture frames that were previously created
    func showAll() {
        for (_, window) in activeFrames {
            window.orderFront(nil)
        }
    }

    /// Remove all capture frames
    func removeAll() {
        for (_, window) in activeFrames {
            window.orderOut(nil)
        }
        activeFrames.removeAll()
    }

    /// Toggle a specific zone's capture frame
    func toggleFrame(for zone: Zone, screen: NSScreen) {
        if let existingWindow = activeFrames[zone.id] {
            existingWindow.orderOut(nil)
            activeFrames.removeValue(forKey: zone.id)
        } else {
            let zoneRect = zone.screenRect(for: screen.frame)
            let window = CaptureFrameWindow(
                zoneId: zone.id,
                zoneName: zone.name,
                frame: zoneRect
            )
            window.orderFront(nil)
            activeFrames[zone.id] = window
        }
    }

    /// Check if a capture frame is currently active for a zone
    func isFrameActive(for zoneId: UUID) -> Bool {
        activeFrames[zoneId]?.isVisible ?? false
    }
}
