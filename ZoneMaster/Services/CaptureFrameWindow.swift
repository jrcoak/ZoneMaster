import AppKit

/// A borderless, transparent, click-through window that covers exactly one zone.
/// Appears in Zoom/Teams/Meet "Share Window" pickers with a descriptive title
/// (e.g., "ZoneMaster — Zone 1"), enabling users to share just one zone's content.
///
/// The window is:
/// - Borderless (no title bar, no chrome)
/// - Transparent (content behind it is fully visible)
/// - Click-through (ignores all mouse events)
/// - Always on top (stays above other windows so it's always capturable)
/// - Non-activating (doesn't steal focus)
///
/// Despite being transparent and click-through, macOS screen sharing tools
/// can still target it by window title, capturing the region it covers.
final class CaptureFrameWindow: NSWindow {

    let zoneId: UUID
    let zoneName: String

    init(zoneId: UUID, zoneName: String, frame: CGRect) {
        self.zoneId = zoneId
        self.zoneName = zoneName

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Window title appears in screen sharing pickers
        self.title = "ZoneMaster — \(zoneName)"

        // Transparent and click-through
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.ignoresMouseEvents = true

        // Stay on top but don't steal focus
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isReleasedWhenClosed = false

        // Add a very subtle border so the window has *some* content for capture tools.
        // Without any content, some sharing tools may skip it.
        let contentView = CaptureFrameContentView(frame: frame)
        self.contentView = contentView
    }

    /// Update the frame to match a zone's screen rect
    func updateFrame(to rect: CGRect) {
        self.setFrame(rect, display: true, animate: false)
        self.contentView?.frame = NSRect(origin: .zero, size: rect.size)
    }
}

/// Minimal content view that draws a barely-visible border.
/// This ensures screen sharing tools recognize the window as having content.
final class CaptureFrameContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Draw a 1px semi-transparent border so the window registers as non-empty
        // for screen capture tools. Opacity is low enough to be invisible in practice.
        NSColor(white: 0.5, alpha: 0.02).setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        path.stroke()
    }
}
