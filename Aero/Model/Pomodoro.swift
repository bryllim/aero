import AppKit
import UserNotifications

struct PomodoroState: Codable, Equatable {
    enum Phase: String, Codable {
        case focus, shortBreak, longBreak

        var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }

        /// The label on the wallpaper board.
        var boardName: String {
            switch self {
            case .focus: "FOCUS"
            case .shortBreak: "BREAK"
            case .longBreak: "LONG BREAK"
            }
        }
    }

    var phase: Phase = .focus
    /// Set while the timer is counting down.
    var endDate: Date?
    /// Set while paused; nil with no end date means the timer is idle.
    var remaining: TimeInterval?
    var completedFocusSessions = 0

    var isRunning: Bool { endDate != nil }
    var isActive: Bool { endDate != nil || remaining != nil }

    func remaining(at date: Date, length: TimeInterval) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return remaining ?? length
    }

    /// Which focus session of the cycle this phase belongs to, 1-based.
    func sessionNumber(of cycleLength: Int) -> Int {
        switch phase {
        case .focus: completedFocusSessions % cycleLength + 1
        case .shortBreak, .longBreak: max(1, (completedFocusSessions - 1) % cycleLength + 1)
        }
    }
}

/// Runs the focus timer and notifies when a phase ends. Durations come from settings.
@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var state: PomodoroState {
        didSet {
            guard state != oldValue else { return }
            save()
            schedule()
        }
    }

    private let settings: () -> AeroSettings
    private var timer: Timer?
    private static let key = "pomodoro.v1"

    init(settings: @escaping () -> AeroSettings) {
        self.settings = settings
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PomodoroState.self, from: data) {
            state = saved
        } else {
            state = PomodoroState()
        }
        // A phase that ended while Aero wasn't running rolls over quietly.
        if let end = state.endDate, end <= Date() { complete(notify: false) }
        schedule()
    }

    func length(of phase: PomodoroState.Phase) -> TimeInterval {
        let s = settings()
        let minutes: Int
        switch phase {
        case .focus: minutes = s.pomodoroFocusMinutes
        case .shortBreak: minutes = s.pomodoroShortBreakMinutes
        case .longBreak: minutes = s.pomodoroLongBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    var remaining: TimeInterval { state.remaining(at: Date(), length: length(of: state.phase)) }

    func toggle() {
        state.isRunning ? pause() : start()
    }

    func start() {
        guard !state.isRunning else { return }
        requestNotificationPermission()
        state.endDate = Date().addingTimeInterval(state.remaining ?? length(of: state.phase))
        state.remaining = nil
    }

    func pause() {
        guard let end = state.endDate else { return }
        state.remaining = max(0, end.timeIntervalSinceNow)
        state.endDate = nil
    }

    func skip() {
        complete(notify: false)
    }

    func reset() {
        state = PomodoroState()
    }

    private func complete(notify: Bool) {
        let finished = state.phase
        var next = state
        if finished == .focus { next.completedFocusSessions += 1 }
        let cycle = settings().pomodoroSessionsPerCycle
        switch finished {
        case .focus:
            next.phase = next.completedFocusSessions % cycle == 0 ? .longBreak : .shortBreak
        case .shortBreak:
            next.phase = .focus
        case .longBreak:
            next.phase = .focus
            next.completedFocusSessions = 0
        }
        if settings().pomodoroAutoStart {
            next.endDate = Date().addingTimeInterval(length(of: next.phase))
            next.remaining = nil
        } else {
            next.endDate = nil
            next.remaining = length(of: next.phase)
        }
        state = next
        if notify { announce(finished: finished, next: next.phase) }
    }

    private func schedule() {
        timer?.invalidate()
        timer = nil
        guard let end = state.endDate else { return }
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.complete(notify: true) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: Notifications

    private var notificationsAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    private func requestNotificationPermission() {
        guard settings().pomodoroNotifications, notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func announce(finished: PomodoroState.Phase, next: PomodoroState.Phase) {
        guard settings().pomodoroNotifications else { return }
        NSSound(named: "Glass")?.play()
        guard notificationsAvailable else { return }
        let content = UNMutableNotificationContent()
        let minutes = Int(length(of: next) / 60)
        switch finished {
        case .focus:
            content.title = "Focus session complete"
            content.body = "Time for a \(minutes)-minute \(next == .longBreak ? "long break" : "break")."
        case .shortBreak, .longBreak:
            content.title = "Break's over"
            content.body = "Ready for a \(minutes)-minute focus session."
        }
        let request = UNNotificationRequest(identifier: "aero.pomodoro", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
