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
        dividerView.screenFrame = screen.frame
        dividerView.needsDisplay = true
        self.setFrame(screen.frame, display: true)
    }

    func showDividers() {
        orderFront(nil)
    }

    func hideDividers() {
        orderOut(nil)
    }
}

/// Custom view that draws thin semi-transparent lines at zone boundaries.
final class DividerOverlayView: NSView {
    var zones: [Zone] = []
    var screenFrame: CGRect = .zero

    private let dividerColor = NSColor(white: 0.5, alpha: 0.3)
    private let dividerWidth: CGFloat = 1.0

    override func draw(_ dirtyRect: NSRect) {
        guard !zones.isEmpty else { return }

        dividerColor.setStroke()

        // Collect unique interior edges
        var verticalEdges = Set<CGFloat>()
        var horizontalEdges = Set<CGFloat>()

        for zone in zones {
            let rect = zone.screenRect(for: screenFrame)

            // Right edge (skip if it's the screen edge)
            let rightEdge = rect.maxX
            if abs(rightEdge - screenFrame.maxX) > 2 {
                verticalEdges.insert(rightEdge - screenFrame.origin.x)
            }

            // Bottom edge (skip if it's the screen edge)
            let bottomEdge = rect.maxY
            if abs(bottomEdge - screenFrame.maxY) > 2 {
                horizontalEdges.insert(bottomEdge - screenFrame.origin.y)
            }
        }

        // Draw vertical dividers
        for x in verticalEdges {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
            path.lineWidth = dividerWidth
            path.stroke()
        }

        // Draw horizontal dividers
        for y in horizontalEdges {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: bounds.width, y: y))
            path.lineWidth = dividerWidth
            path.stroke()
        }
    }
}
