import SwiftUI

/// Interactive editor where users drag divider lines to create custom zone layouts.
/// Dividers can be vertical or horizontal. Dragging creates/moves split lines on a
/// scaled representation of the screen.
struct CustomZoneEditorView: View {
    @Binding var zones: [Zone]
    let onZonesChanged: ([Zone]) -> Void

    @State private var verticalDividers: [CGFloat] = []   // Normalized x positions (0–1)
    @State private var horizontalDividers: [CGFloat] = [] // Normalized y positions (0–1)
    @State private var draggedDivider: DividerID?

    enum DividerID: Hashable {
        case vertical(Int)
        case horizontal(Int)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Drag dividers to define zones. Click + to add, − to remove.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: addVerticalDivider) {
                    Label("V Split", systemImage: "plus")
                        .font(.caption)
                }
                Button(action: addHorizontalDivider) {
                    Label("H Split", systemImage: "plus")
                        .font(.caption)
                }
                if !verticalDividers.isEmpty || !horizontalDividers.isEmpty {
                    Button(action: removeLastDivider) {
                        Label("Remove", systemImage: "minus")
                            .font(.caption)
                    }
                }
            }

            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    // Zone fills
                    let computedZones = computeZones()
                    ForEach(Array(computedZones.enumerated()), id: \.offset) { index, zone in
                        let rect = CGRect(
                            x: zone.normalizedRect.x * geometry.size.width,
                            y: zone.normalizedRect.y * geometry.size.height,
                            width: zone.normalizedRect.width * geometry.size.width,
                            height: zone.normalizedRect.height * geometry.size.height
                        )
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.08))
                            .frame(width: max(0, rect.width - 4), height: max(0, rect.height - 4))
                            .position(x: rect.midX, y: rect.midY)

                        Text("Zone \(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .position(x: rect.midX, y: rect.midY)
                    }

                    // Vertical dividers
                    ForEach(Array(verticalDividers.enumerated()), id: \.offset) { index, pos in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: geometry.size.height)
                            .position(x: pos * geometry.size.width, y: geometry.size.height / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let normalized = min(max(value.location.x / geometry.size.width, 0.05), 0.95)
                                        verticalDividers[index] = normalized
                                    }
                                    .onEnded { _ in
                                        verticalDividers.sort()
                                        updateZones()
                                    }
                            )
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.resizeLeftRight.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                    }

                    // Horizontal dividers
                    ForEach(Array(horizontalDividers.enumerated()), id: \.offset) { index, pos in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width, height: 3)
                            .position(x: geometry.size.width / 2, y: pos * geometry.size.height)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let normalized = min(max(value.location.y / geometry.size.height, 0.05), 0.95)
                                        horizontalDividers[index] = normalized
                                    }
                                    .onEnded { _ in
                                        horizontalDividers.sort()
                                        updateZones()
                                    }
                            )
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.resizeUpDown.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                    }
                }
            }
            .frame(minHeight: 200)
            .onAppear {
                initializeDividersFromZones()
            }
        }
    }

    // MARK: - Divider Management

    private func addVerticalDivider() {
        // Place new divider at the midpoint of the largest gap
        let positions = ([0.0] + verticalDividers + [1.0]).sorted()
        var maxGap: CGFloat = 0
        var insertPos: CGFloat = 0.5
        for i in 0..<(positions.count - 1) {
            let gap = positions[i + 1] - positions[i]
            if gap > maxGap {
                maxGap = gap
                insertPos = (positions[i] + positions[i + 1]) / 2
            }
        }
        verticalDividers.append(insertPos)
        verticalDividers.sort()
        updateZones()
    }

    private func addHorizontalDivider() {
        let positions = ([0.0] + horizontalDividers + [1.0]).sorted()
        var maxGap: CGFloat = 0
        var insertPos: CGFloat = 0.5
        for i in 0..<(positions.count - 1) {
            let gap = positions[i + 1] - positions[i]
            if gap > maxGap {
                maxGap = gap
                insertPos = (positions[i] + positions[i + 1]) / 2
            }
        }
        horizontalDividers.append(insertPos)
        horizontalDividers.sort()
        updateZones()
    }

    private func removeLastDivider() {
        if !verticalDividers.isEmpty {
            verticalDividers.removeLast()
        } else if !horizontalDividers.isEmpty {
            horizontalDividers.removeLast()
        }
        updateZones()
    }

    // MARK: - Zone Computation

    /// Compute zones from the current divider positions.
    /// Vertical dividers create columns, horizontal dividers create rows.
    /// The result is a grid of zones.
    private func computeZones() -> [Zone] {
        let xPositions = ([0.0] + verticalDividers + [1.0]).sorted()
        let yPositions = ([0.0] + horizontalDividers + [1.0]).sorted()

        var result: [Zone] = []
        var index = 1

        for row in 0..<(yPositions.count - 1) {
            for col in 0..<(xPositions.count - 1) {
                let rect = NormalizedRect(
                    x: xPositions[col],
                    y: yPositions[row],
                    width: xPositions[col + 1] - xPositions[col],
                    height: yPositions[row + 1] - yPositions[row]
                )
                result.append(Zone(normalizedRect: rect, name: "Zone \(index)"))
                index += 1
            }
        }

        return result
    }

    private func updateZones() {
        let newZones = computeZones()
        zones = newZones
        onZonesChanged(newZones)
    }

    /// Reverse-engineer divider positions from existing zones
    private func initializeDividersFromZones() {
        guard !zones.isEmpty else { return }

        var xEdges = Set<CGFloat>()
        var yEdges = Set<CGFloat>()

        for zone in zones {
            let r = zone.normalizedRect
            xEdges.insert(r.x)
            xEdges.insert(r.x + r.width)
            yEdges.insert(r.y)
            yEdges.insert(r.y + r.height)
        }

        // Remove 0 and 1 (screen edges), keep only interior dividers
        xEdges.remove(0)
        xEdges.remove(1)
        yEdges.remove(0)
        yEdges.remove(1)

        // Filter out values very close to 0 or 1
        verticalDividers = xEdges.filter { $0 > 0.01 && $0 < 0.99 }.sorted()
        horizontalDividers = yEdges.filter { $0 > 0.01 && $0 < 0.99 }.sorted()
    }
}
