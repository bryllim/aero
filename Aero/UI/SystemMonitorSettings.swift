import SwiftUI

struct SystemMonitorSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            SystemMonitorSettingsSection()
            if model.settings.systemStatsEnabled {
                SystemMonitorReadout(monitor: model.systemMonitor)
            }
        }
        .formStyle(.grouped)
    }
}

struct SystemMonitorSettingsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section {
            Toggle("Show system stats on the wallpaper", isOn: $model.settings.showSystemStatsOnWallpaper)
            if model.settings.showSystemStatsOnWallpaper {
                Toggle("CPU usage", isOn: $model.settings.systemStatsCPU)
                Toggle("RAM used", isOn: $model.settings.systemStatsMemory)
                Toggle("Swap used", isOn: $model.settings.systemStatsSwap)
            }
        } header: {
            Label("System Monitor", systemImage: "cpu")
        } footer: {
            if model.settings.showSystemStatsOnWallpaper && !model.settings.systemStatsEnabled {
                Text("Choose at least one metric to show on the wallpaper.")
            } else {
                Text("Live usage across your Mac. Updates every 2 seconds, in your wallpaper’s colors and display style.")
            }
        }
    }
}

private struct SystemMonitorReadout: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        Section("Live Readings") {
            LabeledContent("CPU") {
                Text(monitor.snapshot.cpuFraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "Sampling…")
            }
            LabeledContent("RAM used") {
                Text(monitor.snapshot.memoryUsedBytes.map {
                    SystemSnapshot.gigabytes($0) + " / " + SystemSnapshot.gigabytes(monitor.snapshot.physicalMemoryBytes) + " GB"
                } ?? "Unavailable")
            }
            LabeledContent("Swap used") {
                Text(monitor.snapshot.swapUsedBytes.map { SystemSnapshot.gigabytes($0) + " GB" } ?? "Unavailable")
            }
        }
        .monospacedDigit()
    }
}
