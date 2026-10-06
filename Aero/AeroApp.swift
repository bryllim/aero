import SwiftUI

@main
struct AeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("Aero", id: "main") {
            MainView()
                .environmentObject(model)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 680)
        .commands {
            CommandMenu("Clock") {
                ClockCommands()
                    .environmentObject(model)
            }
            CommandMenu("Focus") {
                FocusCommands(pomodoro: model.pomodoro)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(model)
        } label: {
            MenuBarLabel(pomodoro: model.pomodoro)
        }
    }
}

extension AeroApp {
    /// The icon's dot-matrix "A", as a template image for the menu bar.
    static let menuBarIcon: NSImage = {
        let glyph = PixelFont.glyph("A")
        let pitch: CGFloat = 2.25, dot: CGFloat = 1.75
        let size = NSSize(width: CGFloat(glyph[0].count) * pitch, height: CGFloat(glyph.count) * pitch)
        let image = NSImage(size: size, flipped: true) { _ in
            for (row, bits) in glyph.enumerated() {
                for (column, on) in bits.enumerated() where on {
                    NSBezierPath(ovalIn: NSRect(x: CGFloat(column) * pitch + (pitch - dot) / 2,
                                                y: CGFloat(row) * pitch + (pitch - dot) / 2, width: dot, height: dot)).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var wallpaper: WallpaperController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        if !model.settings.showInDock { model.applyDockPolicy() }
        wallpaper = WallpaperController(model: model)

        // Started by the system at login: put the clock on the desktop without opening a window.
        let event = NSAppleEventManager.shared().currentAppleEvent
        if event?.eventID == kAEOpenApplication,
           event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            DispatchQueue.main.async {
                NSApp.windows.filter { $0.canBecomeMain }.forEach { $0.close() }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Wallpaper, style, layout and theme controls shared by the Clock menu and the menu bar item.
private struct ClockCommands: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Toggle("Show on Desktop", isOn: $model.settings.wallpaperEnabled)
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Divider()
        Picker("Style", selection: $model.settings.style) {
            ForEach(DisplayStyle.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.inline)
        Picker("Layout", selection: $model.settings.layout) {
            ForEach(ClockLayout.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.inline)
        Menu("Theme") {
            ForEach(Theme.all) { theme in
                Button(theme.name) {
                    model.settings.foregroundHex = theme.foreground
                    model.settings.backgroundHex = theme.background
                }
            }
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var pomodoro: PomodoroTimer
    @StateObject private var ticker = Ticker()

    var body: some View {
        // The status item accepts a single image reliably, so the countdown is drawn into one.
        Image(nsImage: pomodoro.state.endDate.map { AeroApp.menuBarImage(countdown: $0, at: ticker.now) } ?? AeroApp.menuBarIcon)
            .accessibilityLabel("Aero")
            .onChange(of: pomodoro.state.isRunning, initial: true) { _, running in ticker.isRunning = running }
    }
}

/// Publishes the current time once a second while the countdown is showing.
private final class Ticker: ObservableObject {
    @Published var now = Date()
    private var timer: Timer?

    var isRunning = false {
        didSet {
            timer?.invalidate()
            timer = nil
            guard isRunning else { return }
            now = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.now = Date() }
        }
    }
}

extension AeroApp {
    /// The menu bar icon with the remaining focus time beside it.
    static func menuBarImage(countdown end: Date, at now: Date) -> NSImage {
        let text = FocusCard.format(max(0, end.timeIntervalSince(now))) as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium), .foregroundColor: NSColor.black,
        ]
        let textSize = text.size(withAttributes: attributes)
        let icon = menuBarIcon
        let height = max(icon.size.height, textSize.height)
        let image = NSImage(size: NSSize(width: icon.size.width + 5 + ceil(textSize.width), height: height), flipped: false) { _ in
            icon.draw(in: NSRect(x: 0, y: (height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
            text.draw(at: NSPoint(x: icon.size.width + 5, y: (height - textSize.height) / 2), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Start, pause, skip and reset for the focus timer.
private struct FocusCommands: View {
    @ObservedObject var pomodoro: PomodoroTimer

    var body: some View {
        Button(pomodoro.state.isRunning ? "Pause \(pomodoro.state.phase.title)" : "Start \(pomodoro.state.phase.title)",
               action: pomodoro.toggle)
            .keyboardShortcut("p", modifiers: [.command, .option])
        Button("Skip to Next Phase", action: pomodoro.skip)
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(!pomodoro.state.isActive)
        Button("Reset Timer", action: pomodoro.reset)
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(!pomodoro.state.isActive)
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var usage = AppModel.shared.usage
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ClockCommands()
        Divider()
        FocusCommands(pomodoro: model.pomodoro)
        if !usage.snapshot.providers.isEmpty {
            Divider()
            ForEach(UsageProvider.allCases) { provider in
                if let info = usage.snapshot.providers[provider] {
                    Text(provider.title + ": " + info.windows.map {
                        "\(Int(($0.remaining * 100).rounded()))% left (\($0.label.lowercased()))"
                    }.joined(separator: ", "))
                }
            }
        }
        Divider()
        Button("Open Aero") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Aero") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
