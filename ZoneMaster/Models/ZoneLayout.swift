import Foundation

/// Predefined zone layout presets
enum ZonePreset: String, CaseIterable, Codable, Identifiable {
    case threeEqualColumns = "three_equal_columns"
    case twoEqualColumns = "two_equal_columns"
    case twoColumnsOneThirdTwoThirds = "two_columns_1_3_2_3"
    case twoColumnsTwoThirdsOneThird = "two_columns_2_3_1_3"
    case twoEqualRows = "two_equal_rows"
    case grid2x2 = "grid_2x2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeEqualColumns: return "3 Equal Columns"
        case .twoEqualColumns: return "2 Equal Columns"
        case .twoColumnsOneThirdTwoThirds: return "⅓ + ⅔"
        case .twoColumnsTwoThirdsOneThird: return "⅔ + ⅓"
        case .twoEqualRows: return "2 Equal Rows"
        case .grid2x2: return "2×2 Grid"
        }
    }

    var iconName: String {
        switch self {
        case .threeEqualColumns: return "rectangle.split.3x1"
        case .twoEqualColumns: return "rectangle.split.2x1"
        case .twoColumnsOneThirdTwoThirds: return "rectangle.leadinghalf.inset.filled"
        case .twoColumnsTwoThirdsOneThird: return "rectangle.trailinghalf.inset.filled"
        case .twoEqualRows: return "rectangle.split.1x2"
        case .grid2x2: return "rectangle.split.2x2"
        }
    }

    /// Generate zones for this preset
    func generateZones() -> [Zone] {
        switch self {
        case .threeEqualColumns:
            return [
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0, width: 1.0/3.0, height: 1), name: "Zone 1"),
                Zone(normalizedRect: NormalizedRect(x: 1.0/3.0, y: 0, width: 1.0/3.0, height: 1), name: "Zone 2"),
                Zone(normalizedRect: NormalizedRect(x: 2.0/3.0, y: 0, width: 1.0/3.0, height: 1), name: "Zone 3"),
            ]
        case .twoEqualColumns:
            return [
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1), name: "Zone 1"),
                Zone(normalizedRect: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1), name: "Zone 2"),
            ]
        case .twoColumnsOneThirdTwoThirds:
            return [
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0, width: 1.0/3.0, height: 1), name: "Zone 1"),
                Zone(normalizedRect: NormalizedRect(x: 1.0/3.0, y: 0, width: 2.0/3.0, height: 1), name: "Zone 2"),
            ]
        case .twoColumnsTwoThirdsOneThird:
            return [
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0, width: 2.0/3.0, height: 1), name: "Zone 1"),
                Zone(normalizedRect: NormalizedRect(x: 2.0/3.0, y: 0, width: 1.0/3.0, height: 1), name: "Zone 2"),
            ]
        case .twoEqualRows:
            return [
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0, width: 1, height: 0.5), name: "Zone 1"),
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0.5, width: 1, height: 0.5), name: "Zone 2"),
            ]
        case .grid2x2:
            return [
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), name: "Zone 1"),
                Zone(normalizedRect: NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5), name: "Zone 2"),
                Zone(normalizedRect: NormalizedRect(x: 0, y: 0.5, width: 0.5, height: 0.5), name: "Zone 3"),
                Zone(normalizedRect: NormalizedRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5), name: "Zone 4"),
            ]
        }
    }
}

/// Describes how zones are arranged — either from a preset or custom dividers.
enum ZoneLayoutSource: Codable, Equatable {
    case preset(ZonePreset)
    case custom

    enum CodingKeys: String, CodingKey {
        case type, preset
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .preset(let preset):
            try container.encode("preset", forKey: .type)
            try container.encode(preset, forKey: .preset)
        case .custom:
            try container.encode("custom", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "preset":
            let preset = try container.decode(ZonePreset.self, forKey: .preset)
            self = .preset(preset)
        default:
            self = .custom
        }
    }
}
