import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    static let maxCities = 8

    @Published var settings: AeroSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            if settings.showInDock != oldValue.showInDock { applyDockPolicy() }
        }
    }

    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private(set) var pomodoro: PomodoroTimer!
    let usage = UsageMonitor()
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        settings = AeroSettings.load()
        pomodoro = PomodoroTimer { [unowned self] in self.settings }
        usage.configure(settings: settings)
        $settings
            .map { ($0.usageClaude, $0.usageCodex, $0.usageClaudeRefresh) }
            .removeDuplicates { $0 == $1 }
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.usage.configure(settings: self.settings)
            }
            .store(in: &cancellables)
    }

    /// Everything the clock face needs to draw itself.
    var faceInput: FaceInput {
        FaceInput(settings: settings, pomodoro: pomodoro.state,
                  focusLength: pomodoro.length(of: pomodoro.state.phase), usage: usage.snapshot)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Aero: launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(settings.showInDock ? .regular : .accessory)
        if !settings.showInDock {
            // Switching to accessory hides the app's windows; bring them back.
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    func resetAppearance() {
        var fresh = AeroSettings()
        fresh.wallpaperEnabled = settings.wallpaperEnabled
        fresh.displayTarget = settings.displayTarget
        fresh.showInDock = settings.showInDock
        settings = fresh
    }
}
