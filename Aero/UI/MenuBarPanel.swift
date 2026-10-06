import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Aero")
                    .font(.headline)
                Spacer()
                Text("Make time for focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            PomodoroMenuCard(pomodoro: model.pomodoro)
            MenuBarWallpaperControls()
            MenuBarUsage(usage: model.usage)
            MenuBarFooter()
        }
        .padding(16)
        .frame(width: 360)
    }
}

/// A dedicated timer surface, independent of the wallpaper controls.
struct PomodoroMenuCard: View {
    @ObservedObject var pomodoro: PomodoroTimer
    @EnvironmentObject private var model: AppModel

    private var tint: Color { pomodoro.state.phase == .focus ? .orange : .green }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(tint)
                Text("Pomodoro")
                    .font(.headline)
                Spacer()
                Text(pomodoro.state.phase.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12), in: Capsule())
                PomodoroSettingsButton()
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            PomodoroMenuCountdown(state: pomodoro.state,
                                  length: pomodoro.length(of: pomodoro.state.phase), tint: tint)

            PomodoroCycleProgress(state: pomodoro.state,
                                  cycleLength: model.settings.pomodoroSessionsPerCycle, tint: tint)

            PomodoroMenuTransport(pomodoro: pomodoro, tint: tint)

            Text("\(model.settings.pomodoroFocusMinutes) min focus · \(model.settings.pomodoroShortBreakMinutes) min break · \(model.settings.pomodoroLongBreakMinutes) min long break")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0.03)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.22)))
    }
}

private struct PomodoroMenuCountdown: View {
    let state: PomodoroState
    let length: TimeInterval
    let tint: Color

    private var status: LocalizedStringKey {
        if state.isRunning {
            return state.phase == .focus ? "Focus in progress" : "Take a breather"
        }
        if let remaining = state.remaining, remaining < length { return "Paused" }
        return state.phase == .focus ? "Ready to focus" : "Ready for a break"
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !state.isRunning)) { context in
            let remaining = state.remaining(at: context.date, length: length)
            VStack(spacing: 8) {
                Text(FocusCard.format(remaining))
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(FocusCard.format(remaining))
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView(value: min(1, max(0, 1 - remaining / length)))
                    .tint(tint)
                    .accessibilityLabel("Phase progress")
                    .padding(.top, 8)
            }
        }
    }
}

private struct PomodoroCycleProgress: View {
    let state: PomodoroState
    let cycleLength: Int
    let tint: Color

    private var completed: Int {
        state.phase == .longBreak ? cycleLength : state.completedFocusSessions % cycleLength
    }

    var body: some View {
        HStack {
            Text("Session \(state.sessionNumber(of: cycleLength)) of \(cycleLength)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 5) {
                ForEach(0..<cycleLength, id: \.self) { session in
                    Capsule()
                        .fill(session < completed ? tint : tint.opacity(0.18))
                        .frame(width: 12, height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Completed focus sessions")
            .accessibilityValue("\(completed) of \(cycleLength)")
        }
    }
}

private struct PomodoroMenuTransport: View {
    @ObservedObject var pomodoro: PomodoroTimer
    let tint: Color

    private var actionTitle: LocalizedStringKey {
        if pomodoro.state.isRunning { return "Pause" }
        if let remaining = pomodoro.state.remaining, remaining < pomodoro.length(of: pomodoro.state.phase) {
            return "Resume"
        }
        return pomodoro.state.phase == .focus ? "Start Focus" : "Start Break"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: pomodoro.toggle) {
                Label(actionTitle, systemImage: pomodoro.state.isRunning ? "pause.fill" : "play.fill")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(.black)
                    .background(tint, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button(action: pomodoro.skip) {
                Label("Skip to Next Phase", systemImage: "forward.end.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 38)
                    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .help("Skip to the next phase")
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(!pomodoro.state.isActive)

            Button(action: pomodoro.reset) {
                Label("Reset Timer", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 38)
                    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .help("Reset the Pomodoro timer")
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(!pomodoro.state.isActive)
        }
    }
}

private struct MenuBarWallpaperControls: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Desktop Wallpaper", systemImage: "desktopcomputer")
                    .font(.callout.weight(.medium))
                Spacer()
                Toggle("Show on Desktop", isOn: $model.settings.wallpaperEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            Divider()

            HStack {
                Label("System Stats", systemImage: "cpu")
                    .font(.callout)
                Spacer()
                Toggle("Show system stats on the wallpaper", isOn: $model.settings.showSystemStatsOnWallpaper)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button {
                    model.settingsTab = .system
                    openSettings()
                } label: {
                    Label("System Monitor Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Choose CPU, RAM and swap metrics")
            }

            HStack {
                Picker("Style", selection: $model.settings.style) {
                    ForEach(DisplayStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Layout", selection: $model.settings.layout) {
                    ForEach(ClockLayout.allCases) { Text($0.title).tag($0) }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            HStack(spacing: 2) {
                Text("Theme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ForEach(Theme.all) { theme in
                    Button {
                        model.settings.foregroundHex = theme.foreground
                        model.settings.backgroundHex = theme.background
                    } label: {
                        ThemeSwatch(theme: theme, selected: theme.foreground == model.settings.foregroundHex
                                    && theme.background == model.settings.backgroundHex)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MenuBarUsage: View {
    @ObservedObject var usage: UsageMonitor

    var body: some View {
        if !usage.snapshot.providers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(UsageProvider.allCases) { provider in
                    if let info = usage.snapshot.providers[provider] {
                        Text(provider.title + ": " + info.windows.map {
                            "\(Int(($0.remaining * 100).rounded()))% left (\($0.label.lowercased()))"
                        }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

private struct MenuBarFooter: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Aero", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.plain)
            Spacer()
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help("App settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Aero", systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .help("Quit Aero")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
