import SwiftUI

/// The clock itself. Sizes everything relative to its bounds, so the same view
/// serves as the desktop wallpaper and as the preview.
struct ClockFaceView: View {
    let input: FaceInput

    init(input: FaceInput) { self.input = input }
    init(settings: AeroSettings) { input = FaceInput(settings: settings) }

    var body: some View {
        TimelineView(schedule) { timeline in
            Canvas { context, size in
                ClockRenderer.draw(&context, size: size, input: input, date: timeline.date)
            }
        }
        .background(Color(hex: input.settings.backgroundHex).opacity(input.settings.backgroundOpacity))
    }

    private var schedule: BurstSchedule {
        let input = input
        let animated = input.settings.style == .flap && input.settings.flapAnimation
        return BurstSchedule(tick: input.settings.blinkColon ? 0.5 : 1) { tick in
            guard animated else { return 0 }
            // Flips start on the second; a half-second tick inherits whatever is left of them.
            let second = tick.rounded(.down)
            let before = ClockScene.lines(input, at: Date(timeIntervalSinceReferenceDate: second - 0.5))
            let after = ClockScene.lines(input, at: Date(timeIntervalSinceReferenceDate: second))
            return max(0, FlapRenderer.duration(from: before, to: after) - (tick - second))
        }
    }
}

/// Updates once per tick, plus a short run of animation frames after any tick
/// that needs them. Keeps an idle wallpaper from redrawing at display rate.
struct BurstSchedule: TimelineSchedule {
    /// Seconds between ticks; ticks are aligned to whole multiples of this.
    let tick: TimeInterval
    /// Seconds of animation wanted after the tick at the given reference time.
    let burst: (TimeInterval) -> TimeInterval

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(start: startDate, tick: tick, burst: mode == .lowFrequency ? { _ in 0 } : burst)
    }

    struct Entries: Sequence, IteratorProtocol {
        private static let frameRate = 60.0

        private let start: Date
        private let tick: TimeInterval
        private let burst: (TimeInterval) -> TimeInterval
        private var tickIndex: Int
        private var frame = 0
        private var burstLength: TimeInterval
        private var emittedStart = false

        init(start: Date, tick: TimeInterval, burst: @escaping (TimeInterval) -> TimeInterval) {
            self.start = start
            self.tick = tick
            self.burst = burst
            tickIndex = Int((start.timeIntervalSinceReferenceDate / tick).rounded(.down))
            burstLength = burst(Double(tickIndex) * tick)
        }

        mutating func next() -> Date? {
            if !emittedStart {
                emittedStart = true
                return start
            }
            while true {
                frame += 1
                let offset = Double(frame) / Self.frameRate
                if offset <= burstLength, offset < tick {
                    let date = Date(timeIntervalSinceReferenceDate: Double(tickIndex) * tick + offset)
                    if date > start { return date }
                    continue
                }
                tickIndex += 1
                frame = 0
                let time = Double(tickIndex) * tick
                burstLength = burst(time)
                return Date(timeIntervalSinceReferenceDate: time)
            }
        }
    }
}
