import SwiftUI

struct MainView: View {
    @State private var showInspector = true

    var body: some View {
        PreviewPane()
            .inspector(isPresented: $showInspector) {
                Inspector()
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 420)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("Toggle Inspector", systemImage: "sidebar.trailing")
                    }
                    .help(showInspector ? "Hide Inspector" : "Show Inspector")
                }
            }
            .frame(minWidth: 760, minHeight: 480)
    }
}

private struct PreviewPane: View {
    @EnvironmentObject private var model: AppModel

    @State private var desktopPicture: NSImage?

    private var screenSize: CGSize {
        NSScreen.main?.frame.size ?? CGSize(width: 16, height: 10)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FocusCard(pomodoro: model.pomodoro)

                LiveFace(model: model, pomodoro: model.pomodoro, usage: model.usage, systemMonitor: model.systemMonitor)
                    .aspectRatio(screenSize.width / screenSize.height, contentMode: .fit)
                    .background {
                        // What shows through when the background is see-through.
                        if let desktopPicture {
                            Image(nsImage: desktopPicture).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [Color(white: 0.4), Color(white: 0.15)], startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
                    .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                    .accessibilityLabel("Wallpaper preview")

                HStack(alignment: .top, spacing: 24) {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 8) {
                        if model.settings.wallpaperEnabled {
                            Button("Remove from Desktop") { model.settings.wallpaperEnabled = false }
                        } else {
                            Button("Set as Desktop Wallpaper") { model.settings.wallpaperEnabled = true }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.defaultAction)
                        }
                        Text(model.settings.wallpaperEnabled ? "Aero is showing on your desktop." : "Aero isn’t on your desktop yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .controlSize(.large)
                }
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.default, value: model.settings.wallpaperEnabled)
        .task {
            if let screen = NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                desktopPicture = NSImage(contentsOf: url)
            }
        }
    }
}

/// The Pomodoro timer stays above the wallpaper preview.
struct FocusCard: View {
    @ObservedObject var pomodoro: PomodoroTimer
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GroupBox {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    FocusReadout(state: pomodoro.state, remaining: pomodoro.remaining,
                                 cycleLength: model.settings.pomodoroSessionsPerCycle)
                    Spacer(minLength: 0)
                    FocusControls(pomodoro: pomodoro)
                }
                VStack(alignment: .leading, spacing: 12) {
                    FocusReadout(state: pomodoro.state, remaining: pomodoro.remaining,
                                 cycleLength: model.settings.pomodoroSessionsPerCycle)
                    FocusControls(pomodoro: pomodoro)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Label("Pomodoro", systemImage: "timer")
                    .font(.headline)
                Spacer()
                PomodoroSettingsButton()
                    .font(.callout)
            }
        }
        .animation(.default, value: pomodoro.state.isRunning)
    }

    static func format(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct FocusReadout: View {
    let state: PomodoroState
    let remaining: TimeInterval
    let cycleLength: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Group {
                    if let end = state.endDate {
                        let now = Date()
                        Text(timerInterval: now...max(now, end), countsDown: true)
                    } else {
                        Text(FocusCard.format(remaining))
                    }
                }
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .fixedSize()
                Text(state.phase.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text("Session \(state.sessionNumber(of: cycleLength)) of \(cycleLength)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FocusControls: View {
    @ObservedObject var pomodoro: PomodoroTimer

    private var actionTitle: LocalizedStringKey {
        if pomodoro.state.isRunning { return "Pause" }
        return "Start \(pomodoro.state.phase.title)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: pomodoro.toggle) {
                Label(actionTitle, systemImage: pomodoro.state.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            Button(action: pomodoro.skip) {
                Label("Skip", systemImage: "forward.end.fill")
            }
            .help("Skip to the next phase")
            .disabled(!pomodoro.state.isActive)
            Button(action: pomodoro.reset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .help("Reset the Pomodoro timer")
            .disabled(!pomodoro.state.isActive)
        }
        .controlSize(.large)
        .fixedSize()
    }
}

struct PomodoroSettingsButton: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            model.settingsTab = .pomodoro
            openSettings()
        } label: {
            Label("Pomodoro Settings…", systemImage: "gearshape")
        }
        .help("Customize focus sessions, breaks and notifications")
    }
}

private struct Inspector: View {
    @State private var showPomodoro = true

    var body: some View {
        VStack(spacing: 0) {
            Picker("Controls", selection: $showPomodoro) {
                Text("Pomodoro").tag(true)
                Text("Wallpaper").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            if showPomodoro {
                FocusSettings()
            } else {
                WallpaperInspector()
            }
        }
    }
}

private struct WallpaperInspector: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmingReset = false

    var body: some View {
        Form {
            SystemMonitorSettingsSection()
            Section("Display") {
                Picker("Style", selection: $model.settings.style) {
                    ForEach(DisplayStyle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Layout", selection: $model.settings.layout) {
                    ForEach(ClockLayout.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Appearance") {
                LabeledContent("Theme") {
                    HStack(spacing: 2) {
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
                ColorPicker("Display color", selection: color($model.settings.foregroundHex), supportsOpacity: false)
                ColorPicker("Background color", selection: color($model.settings.backgroundHex), supportsOpacity: false)
                Slider(value: $model.settings.backgroundOpacity, in: 0...1) { Text("Background opacity") }
                Slider(value: $model.settings.brightness, in: 0.15...1) {
                    Text("Brightness")
                } minimumValueLabel: {
                    Image(systemName: "sun.min")
                } maximumValueLabel: {
                    Image(systemName: "sun.max")
                }
            }

            Section("Time") {
                Toggle("24-hour time", isOn: $model.settings.use24Hour)
                Toggle("Show seconds", isOn: $model.settings.showSeconds)
                Toggle("Flash the time separators", isOn: $model.settings.blinkColon)
                Toggle("Show date", isOn: $model.settings.showDate)
                if model.settings.showDate {
                    Picker("Date format", selection: $model.settings.dateFormat) {
                        ForEach(DateFormatStyle.allCases) { Text($0.title).tag($0) }
                    }
                }
                TextField("Caption", text: $model.settings.caption, prompt: Text("GATE A12"))
                    .onChange(of: model.settings.caption) { _, caption in
                        if caption.count > 28 { model.settings.caption = String(caption.prefix(28)) }
                    }
            }

            if model.settings.style == .matrix {
                Section("Dot Matrix") {
                    Picker("Dot shape", selection: $model.settings.dotShape) {
                        ForEach(DotShape.allCases) { Text($0.title).tag($0) }
                    }
                    Slider(value: $model.settings.dotFill, in: 0.4...1) { Text("Dot size") }
                    Slider(value: $model.settings.ghost, in: 0...0.3) { Text("Unlit dots") }
                    Slider(value: $model.settings.glow, in: 0...1) { Text("Glow") }
                }
            } else {
                Section("Split-Flap") {
                    Picker("Typeface", selection: $model.settings.flapTypeface) {
                        ForEach(FlapTypeface.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Animate flips", isOn: $model.settings.flapAnimation)
                }
            }

            Section("Placement") {
                Slider(value: $model.settings.scale, in: 0.15...1) {
                    Text("Size")
                } minimumValueLabel: {
                    Image(systemName: "textformat.size.smaller")
                } maximumValueLabel: {
                    Image(systemName: "textformat.size.larger")
                }
                LabeledContent("Position") {
                    AnchorGrid(selection: $model.settings.anchor)
                }
            }

            if model.settings.layout == .map {
                Section("World Map") {
                    Picker("Detail", selection: $model.settings.mapDetail) {
                        ForEach(MapDetail.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Show daylight", isOn: $model.settings.mapDaylight)
                    Toggle("Label destinations", isOn: $model.settings.mapLabels)
                }
            }

            if model.settings.layout != .clock {
                DestinationsSection()
            }

            Section {
                Button("Restore Defaults…") { confirmingReset = true }
            }
        }
        .formStyle(.grouped)
        .animation(.default, value: model.settings.style)
        .animation(.default, value: model.settings.layout)
        .animation(.default, value: model.settings.showDate)
        .animation(.default, value: model.settings.cities)
        .confirmationDialog("Restore the default clock?", isPresented: $confirmingReset) {
            Button("Restore Defaults", role: .destructive) { model.resetAppearance() }
        } message: {
            Text("Your style, colors, placement and destinations will be replaced.")
        }
    }

    private func color(_ hex: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(hex: hex.wrappedValue) }, set: { hex.wrappedValue = RGB($0).hex })
    }
}

private struct DestinationsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section {
            ForEach(model.settings.cities.compactMap(City.find)) { city in
                LabeledContent {
                    Button {
                        model.settings.cities.removeAll { $0 == city.code }
                    } label: {
                        Label("Remove \(city.name.capitalized)", systemImage: "minus.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(city.name.capitalized)")
                } label: {
                    Text(city.name.capitalized)
                    Text(city.code)
                }
                .contextMenu {
                    Button("Move Up") { move(city, by: -1) }
                        .disabled(model.settings.cities.first == city.code)
                    Button("Move Down") { move(city, by: 1) }
                        .disabled(model.settings.cities.last == city.code)
                    Divider()
                    Button("Remove") { model.settings.cities.removeAll { $0 == city.code } }
                }
            }

            Menu("Add Destination") {
                ForEach(City.all.filter { !model.settings.cities.contains($0.code) }) { city in
                    Button("\(city.name.capitalized) (\(city.code))") { model.settings.cities.append(city.code) }
                }
            }
            .disabled(model.settings.cities.count >= AppModel.maxCities)
        } header: {
            Text("Destinations")
        } footer: {
            if model.settings.cities.count >= AppModel.maxCities {
                Text("Aero shows up to \(AppModel.maxCities) destinations.")
            }
        }
    }
}

private extension DestinationsSection {
    func move(_ city: City, by offset: Int) {
        guard let index = model.settings.cities.firstIndex(of: city.code) else { return }
        model.settings.cities.swapAt(index, index + offset)
    }
}

/// The Settings window (⌘,): app behavior, as opposed to how the clock looks.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.settingsTab) {
            FocusSettings()
                .tabItem { Label("Pomodoro", systemImage: "timer") }
                .tag(SettingsTab.pomodoro)
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            SystemMonitorSettings()
                .tabItem { Label("System", systemImage: "cpu") }
                .tag(SettingsTab.system)
            UsageSettings()
                .tabItem { Label("AI Usage", systemImage: "chart.bar.xaxis") }
                .tag(SettingsTab.usage)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                Toggle("Show in Dock", isOn: $model.settings.showInDock)
            } footer: {
                Text("Aero stays available from the menu bar when it’s hidden from the Dock.")
            }
            Section {
                Picker("Show wallpaper on", selection: $model.settings.displayTarget) {
                    ForEach(DisplayTarget.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct FocusSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Stepper("Focus session: \(model.settings.pomodoroFocusMinutes) min",
                        value: $model.settings.pomodoroFocusMinutes, in: 5...90, step: 5)
                Stepper("Short break: \(model.settings.pomodoroShortBreakMinutes) min",
                        value: $model.settings.pomodoroShortBreakMinutes, in: 1...30)
                Stepper("Long break: \(model.settings.pomodoroLongBreakMinutes) min",
                        value: $model.settings.pomodoroLongBreakMinutes, in: 5...60, step: 5)
                Stepper("Sessions per cycle: \(model.settings.pomodoroSessionsPerCycle)",
                        value: $model.settings.pomodoroSessionsPerCycle, in: 2...8)
            } header: {
                Text("Session Lengths")
            } footer: {
                Text("Changes apply from the next phase. An idle timer updates immediately.")
            }
            Section {
                Toggle("Start the next phase automatically", isOn: $model.settings.pomodoroAutoStart)
                Toggle("Notify when a phase ends", isOn: $model.settings.pomodoroNotifications)
                Toggle("Show the timer on the wallpaper", isOn: $model.settings.showPomodoroOnWallpaper)
            } header: {
                Text("Timer Behavior")
            }
        }
        .formStyle(.grouped)
    }
}

private struct UsageSettings: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var usage = AppModel.shared.usage

    var body: some View {
        Form {
            Section {
                Toggle("Claude", isOn: $model.settings.usageClaude)
                if model.settings.usageClaude {
                    status(for: .claude)
                    Toggle("Refresh Claude Code’s sign-in when it expires", isOn: $model.settings.usageClaudeRefresh)
                }
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Reads the sign-in that Claude Code keeps in your keychain; macOS will ask you to allow it. With refresh on, Aero renews the sign-in and hands the new tokens back to Claude Code.")
            }
            Section {
                Toggle("ChatGPT Codex", isOn: $model.settings.usageCodex)
                if model.settings.usageCodex { status(for: .codex) }
            } header: {
                Text("Codex")
            } footer: {
                Text("Reads the sign-in from the Codex CLI in ~/.codex. Nothing is stored or sent anywhere except to each provider.")
            }
            Section {
                Toggle("Show usage on the wallpaper", isOn: $model.settings.showUsageOnWallpaper)
                LabeledContent("Checked every 5 minutes") {
                    Button("Refresh Now") { Task { await usage.refresh() } }
                        .disabled(usage.isRefreshing || !(model.settings.usageClaude || model.settings.usageCodex))
                }
            }
        }
        .formStyle(.grouped)
        .animation(.default, value: model.settings.usageClaude)
        .animation(.default, value: model.settings.usageCodex)
    }

    @ViewBuilder
    private func status(for provider: UsageProvider) -> some View {
        if let error = usage.snapshot.errors[provider] {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else if let info = usage.snapshot.providers[provider] {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(info.windows, id: \.label) { window in
                    HStack {
                        Text(Self.describe(window.label))
                        Spacer()
                        Text("\(Int((window.remaining * 100).rounded()))% left")
                            .monospacedDigit()
                        if let resets = window.resetsAt {
                            Text("· resets \(resets, style: .relative)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.callout)
        } else if usage.isRefreshing {
            ProgressView().controlSize(.small)
        }
    }

    private static func describe(_ label: String) -> String {
        switch label {
        case "5H": "5-hour window"
        case "7D": "Weekly window"
        default: label.lowercased() + " window"
        }
    }
}
