import SwiftUI

/// Grid of preset layout thumbnails for quick zone selection
struct PresetPickerView: View {
    let selectedPreset: ZonePreset?
    let onSelect: (ZonePreset) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ZonePreset.allCases) { preset in
                PresetThumbnail(
                    preset: preset,
                    isSelected: selectedPreset == preset
                )
                .onTapGesture {
                    onSelect(preset)
                }
            }
        }
    }
}

/// Visual thumbnail showing a preset layout
struct PresetThumbnail: View {
    let preset: ZonePreset
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZonePreviewShape(zones: preset.generateZones())
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )

            Text(preset.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(4)
    }
}

/// Draws a miniature preview of zone layout
struct ZonePreviewShape: View {
    let zones: [Zone]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(zones) { zone in
                    let rect = CGRect(
                        x: zone.normalizedRect.x * geometry.size.width,
                        y: zone.normalizedRect.y * geometry.size.height,
                        width: zone.normalizedRect.width * geometry.size.width,
                        height: zone.normalizedRect.height * geometry.size.height
                    )

                    Rectangle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: rect.width - 2, height: rect.height - 2)
                        .position(x: rect.midX, y: rect.midY)

                    Rectangle()
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                        .frame(width: rect.width - 2, height: rect.height - 2)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}
