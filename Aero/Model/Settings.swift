import SwiftUI

protocol SettingOption: CaseIterable, Identifiable, Hashable, Codable where AllCases: RandomAccessCollection {
    var title: String { get }
}

extension SettingOption where Self: RawRepresentable, RawValue == String {
    var id: String { rawValue }
}

enum DisplayStyle: String, SettingOption {
    case matrix, flap
    var title: String { self == .matrix ? "Dot Matrix" : "Split-Flap" }
}

enum ClockLayout: String, SettingOption {
    case clock, board, map
    var title: String {
        switch self {
        case .clock: "Clock"
        case .board: "Departures"
        case .map: "World Map"
        }
    }
}

enum MapDetail: String, SettingOption {
    case coarse, standard, fine
    var title: String { rawValue.capitalized }

    /// Degrees of longitude and latitude per dot.
    var step: Double {
        switch self {
        case .coarse: 4
        case .standard: 3
        case .fine: 2
        }
    }
}

enum DotShape: String, SettingOption {
    case round, square
    var title: String { self == .round ? "Round" : "Square" }
}

enum FlapTypeface: String, SettingOption {
    case pixel, classic
    var title: String { self == .pixel ? "Pixel" : "Classic" }
}

enum DateFormatStyle: String, SettingOption {
    case weekdayDayMonth, dayMonthYear, full, iso
    var title: String {
        switch self {
        case .weekdayDayMonth: "MON 05 OCT"
        case .dayMonthYear: "05 OCT 2026"
        case .full: "MONDAY 05 OCTOBER"
        case .iso: "2026-10-05"
        }
    }
}

enum DisplayTarget: String, SettingOption {
    case all, main
    var title: String { self == .all ? "All Displays" : "Main Only" }
}

enum Anchor: String, SettingOption {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing

    var title: String { rawValue }

    /// Horizontal and vertical position as fractions of the free space.
    var unit: (x: CGFloat, y: CGFloat) {
        let index = Anchor.allCases.firstIndex(of: self)!
        return (CGFloat(index % 3) / 2, CGFloat(index / 3) / 2)
    }
}

struct Theme: Identifiable, Hashable {
    let name: String
    let foreground: String
    let background: String
    var id: String { name }

    static let all: [Theme] = [
        Theme(name: "Mono", foreground: "FFFFFF", background: "000000"),
        Theme(name: "Amber", foreground: "FFB000", background: "0A0600"),
        Theme(name: "Phosphor", foreground: "3DFF74", background: "020A04"),
        Theme(name: "Signal", foreground: "FF3B30", background: "0A0202"),
        Theme(name: "Ice", foreground: "9FE8FF", background: "02080C"),
        Theme(name: "Paper", foreground: "111111", background: "F2F0EB"),
    ]
}

struct AeroSettings: Codable, Equatable {
    var wallpaperEnabled = false
    var displayTarget: DisplayTarget = .all
    var showInDock = true

    var style: DisplayStyle = .matrix
    var layout: ClockLayout = .clock

    var foregroundHex = "FFFFFF"
    var backgroundHex = "000000"
    var backgroundOpacity = 1.0
    var brightness = 1.0

    var use24Hour = true
    var showSeconds = false
    var blinkColon = true
    var showDate = true
    var dateFormat: DateFormatStyle = .weekdayDayMonth
    var caption = ""

    var scale = 0.55
    var anchor: Anchor = .center

    var dotShape: DotShape = .round
    var dotFill = 0.76
    var ghost = 0.07
    var glow = 0.35

    var flapTypeface: FlapTypeface = .pixel
    var flapAnimation = true

    var mapDetail: MapDetail = .standard
    var mapDaylight = true
    var mapLabels = true

    var pomodoroFocusMinutes = 25
    var pomodoroShortBreakMinutes = 5
    var pomodoroLongBreakMinutes = 15
    var pomodoroSessionsPerCycle = 4
    var pomodoroAutoStart = false
    var pomodoroNotifications = true
    var showPomodoroOnWallpaper = true

    var showSystemStatsOnWallpaper = false
    var systemStatsCPU = true
    var systemStatsMemory = true
    var systemStatsSwap = false

    var systemStatsEnabled: Bool {
        showSystemStatsOnWallpaper && (systemStatsCPU || systemStatsMemory || systemStatsSwap)
    }

    var usageClaude = false
    var usageClaudeRefresh = false
    var usageCodex = false
    var showUsageOnWallpaper = true

    var cities = ["LHR", "JFK", "HND", "SYD", "DXB"]

    private static let key = "settings.v1"

    static func load() -> AeroSettings {
        guard let data = UserDefaults.standard.data(forKey: key) else { return AeroSettings() }
        if let settings = try? JSONDecoder().decode(AeroSettings.self, from: data) { return settings }
        // Saved by an older version: overlay what was saved onto the current defaults.
        if let defaults = try? JSONEncoder().encode(AeroSettings()),
           let base = try? JSONSerialization.jsonObject(with: defaults) as? [String: Any],
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let merged = try? JSONSerialization.data(withJSONObject: base.merging(saved) { _, new in new }),
           let settings = try? JSONDecoder().decode(AeroSettings.self, from: merged) {
            return settings
        }
        return AeroSettings()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

struct RGB: Equatable {
    var r: Double, g: Double, b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFFFFFF
        r = Double((value >> 16) & 0xFF) / 255
        g = Double((value >> 8) & 0xFF) / 255
        b = Double(value & 0xFF) / 255
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        r = Double(ns.redComponent); g = Double(ns.greenComponent); b = Double(ns.blueComponent)
    }

    var hex: String {
        String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }

    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

extension Color {
    init(hex: String) { self = RGB(hex: hex).color }
}
