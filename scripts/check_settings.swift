import SwiftUI

@main
struct SettingsChecks {
    static func main() {
        var settings = AeroSettings()
        settings.wallpaperEnabled = true
        settings.displayTarget = .main
        settings.showInDock = false
        settings.pomodoroFocusMinutes = 40
        settings.pomodoroAutoStart = true
        settings.usageClaude = true
        settings.usageClaudeRefresh = true
        settings.usageCodex = true
        settings.showSystemStatsOnWallpaper = true
        settings.systemStatsSwap = true
        settings.layout = .map
        settings.foregroundHex = "FFB000"
        settings.cities = ["JFK"]

        settings.resetAppearance()

        assert(settings.layout == .clock && settings.foregroundHex == "FFFFFF")
        assert(settings.cities == AeroSettings().cities)
        assert(settings.wallpaperEnabled && settings.displayTarget == .main && !settings.showInDock)
        assert(settings.pomodoroFocusMinutes == 40 && settings.pomodoroAutoStart)
        assert(settings.usageClaude && settings.usageClaudeRefresh && settings.usageCodex)
        assert(settings.showSystemStatsOnWallpaper && settings.systemStatsSwap)
        print("Settings checks passed: restoring appearance preserves app and feature preferences.")
    }
}
