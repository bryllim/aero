import AppKit
import Combine
import SwiftUI

/// Owns one borderless window per display, pinned just above the system
/// wallpaper and below the desktop icons.
@MainActor
final class WallpaperController {
    private let model: AppModel
    private var windows: [NSWindow] = []
    private var observers: [Any] = []
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model

        model.$settings
            .map { Placement(enabled: $0.wallpaperEnabled, target: $0.displayTarget) }
            .removeDuplicates()
            .sink { [weak self] in self?.rebuild($0) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuild(Placement(enabled: self.model.settings.wallpaperEnabled, target: self.model.settings.displayTarget))
            }
            .store(in: &cancellables)
    }

    private func fade(_ windows: [NSWindow], to alpha: CGFloat, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            windows.forEach { $0.animator().alphaValue = alpha }
        }, completionHandler: completion)
    }

    private struct Placement: Equatable {
        var enabled: Bool
        var target: DisplayTarget
    }

    private func rebuild(_ placement: Placement) {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        let retired = windows
        windows = []
        fade(retired, to: 0) { retired.forEach { $0.close() } }
        guard placement.enabled else { return }

        let screens = placement.target == .all ? NSScreen.screens : NSScreen.screens.prefix(1).map { $0 }
        for screen in screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.canHide = false

            let visibility = WindowVisibility()
            window.contentView = NSHostingView(rootView: WallpaperView(model: model, visibility: visibility))
            window.setFrame(screen.frame, display: true)
            window.alphaValue = 0
            window.orderFront(nil)
            fade([window], to: 1)

            // Stop drawing while the desktop is completely covered.
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak window] _ in
                guard let window else { return }
                visibility.isVisible = window.occlusionState.contains(.visible)
            })
            windows.append(window)
        }
    }
}

private final class WindowVisibility: ObservableObject {
    @Published var isVisible = true
}

private struct WallpaperView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var visibility: WindowVisibility

    var body: some View {
        LiveFace(model: model, pomodoro: model.pomodoro, usage: model.usage,
                 systemMonitor: model.systemMonitor, visible: visibility.isVisible)
            .ignoresSafeArea()
    }
}

/// Observes every source of change the face depends on.
struct LiveFace: View {
    @ObservedObject var model: AppModel
    @ObservedObject var pomodoro: PomodoroTimer
    @ObservedObject var usage: UsageMonitor
    @ObservedObject var systemMonitor: SystemMonitor
    var visible = true

    var body: some View {
        Group {
            if visible {
                ClockFaceView(input: model.faceInput)
            } else {
                Color.clear
            }
        }
    }
}
