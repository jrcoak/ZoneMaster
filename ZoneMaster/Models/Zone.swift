import Foundation
import CoreGraphics

/// A rectangular region of the screen that acts as a virtual display boundary.
struct Zone: Identifiable, Codable, Equatable {
    let id: UUID
    /// Normalized rect (0.0–1.0) relative to the screen bounds.
    /// Converted to pixel coordinates at runtime using the active screen's frame.
    var normalizedRect: NormalizedRect
    /// User-facing label (e.g., "Zone 1", "Left Panel")
    var name: String
    /// Whether the capture frame window is enabled for this zone
    var captureFrameEnabled: Bool

    init(
        id: UUID = UUID(),
        normalizedRect: NormalizedRect,
        name: String,
        captureFrameEnabled: Bool = false
    ) {
        self.id = id
        self.normalizedRect = normalizedRect
        self.name = name
        self.captureFrameEnabled = captureFrameEnabled
    }

    /// Convert normalized rect to screen pixel coordinates
    func screenRect(for screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.origin.x + normalizedRect.x * screenFrame.width,
            y: screenFrame.origin.y + normalizedRect.y * screenFrame.height,
            width: normalizedRect.width * screenFrame.width,
            height: normalizedRect.height * screenFrame.height
        )
    }

    /// Minimum zone dimension in pixels
    static let minimumSize: CGFloat = 400
}

/// A rect with values normalized to 0.0–1.0, independent of screen resolution.
struct NormalizedRect: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(from cgRect: CGRect) {
        self.x = cgRect.origin.x
        self.y = cgRect.origin.y
        self.width = cgRect.size.width
        self.height = cgRect.size.height
    }
}
