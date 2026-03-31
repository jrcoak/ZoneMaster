import AppKit

/// A transparent, click-through overlay window that draws subtle divider lines
/// between zones. Covers the entire screen but is invisible except for the dividers.
final class DividerOverlayWindow: NSWindow {

    private let dividerView: DividerOverlayView

    init(screen: NSScreen) {
        self.dividerView = DividerOverlayView(frame: screen.frame)

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isReleasedWhenClosed = false
        self.contentView = dividerView
    }

    /// Update the divider positions based on current zones
    func updateDividers(zones: [Zone], screen: NSScreen) {
        dividerView.zones = zones
        self.setFrame(screen.frame, display: true)
        dividerView.needsDisplay = true
    }

    func showDividers() {
        orderFront(nil)
    }

    func hideDividers() {
        orderOut(nil)
    }
}

/// Custom view that draws thin semi-transparent lines at zone boundaries.
/// Uses normalized zone coordinates directly, converting to view-local pixels.
/// The view fills the entire screen, so (0,0) is the screen's bottom-left corner.
final class DividerOverlayView: NSView {
    var zones: [Zone] = []

    private let dividerColor = NSColor(white: 0.4, alpha: 0.5)
    private let dividerWidth: CGFloat = 2.0

    override func draw(_ dirtyRect: NSRect) {
        guard !zones.isEmpty else { return }

        dividerColor.setStroke()

        // Collect unique interior edges from normalized coordinates.
        // Values at 0.0 and 1.0 are screen edges — skip them.
        var verticalPositions = Set<CGFloat>()
        var horizontalPositions = Set<CGFloat>()

        for zone in zones {
            let r = zone.normalizedRect
            // Right edge of this zone
            let rightNorm = r.x + r.width
            if rightNorm > 0.01 && rightNorm < 0.99 {
                verticalPositions.insert(rightNorm)
            }
            // Top edge of this zone (in normalized space, y increases downward
            // but NSView y increases upward — we'll flip when drawing)
            let bottomNorm = r.y + r.height
            if bottomNorm > 0.01 && bottomNorm < 0.99 {
                horizontalPositions.insert(bottomNorm)
            }
        }

        let w = bounds.width
        let h = bounds.height

        // Draw vertical dividers (full height of screen)
        for normX in verticalPositions {
            let x = normX * w
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: h))
            path.lineWidth = dividerWidth
            path.stroke()
        }

        // Draw horizontal dividers (full width of screen)
        // Normalized y=0 is top of screen, but NSView y=0 is bottom — flip
        for normY in horizontalPositions {
            let y = h - (normY * h)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: w, y: y))
            path.lineWidth = dividerWidth
            path.stroke()
        }
    }
}
