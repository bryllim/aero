import Foundation

/// Everything that varies on the face: settings plus live state.
struct FaceInput: Equatable {
    var settings: AeroSettings
    var pomodoro = PomodoroState()
    /// Full length of the current pomodoro phase, for the progress bar.
    var focusLength: TimeInterval = 25 * 60
    var usage = UsageSnapshot()
}

/// One row of the display: text plus its size relative to the main time row.
struct SceneLine: Equatable {
    enum Kind: Equatable {
        case text
        case map
        /// A dotted progress bar, filled to the given fraction.
        case bar(Double)
    }

    var text: String
    var weight: CGFloat
    var dim = false
    var kind: Kind = .text
    var isText: Bool { kind == .text }
    /// Space below this line, in units of the main row height.
    var gapAfter: CGFloat = 0.1
}

/// Turns settings and a moment in time into the rows to show.
enum ClockScene {
    private static let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let weekdaysFull = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private static let monthsFull = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST",
                                     "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    static func lines(_ input: FaceInput, at date: Date) -> [SceneLine] {
        let settings = input.settings
        let local = TimeZone.current
        let parts = components(date, in: local)
        let seconds = date.timeIntervalSinceReferenceDate
        let colonLit = !settings.blinkColon || seconds - seconds.rounded(.down) < 0.5
        let colon = String(colonLit ? ":" : PixelFont.blankColon)

        var out = [SceneLine(text: timeText(parts, settings: settings, colon: colon), weight: 1, gapAfter: 0.16)]

        if settings.showDate {
            out.append(SceneLine(text: dateText(parts, format: settings.dateFormat), weight: 0.26, gapAfter: 0.12))
        }
        let caption = PixelFont.sanitize(settings.caption).trimmingCharacters(in: .whitespaces)
        if !caption.isEmpty {
            out.append(SceneLine(text: caption, weight: 0.26, dim: true))
        }

        if settings.showPomodoroOnWallpaper, input.pomodoro.isActive {
            let state = input.pomodoro
            let remaining = state.remaining(at: date, length: input.focusLength)
            let progress = input.focusLength > 0 ? 1 - remaining / input.focusLength : 0
            let seconds = Int(remaining.rounded(.up))
            let pausedMidway = !state.isRunning && (state.remaining ?? input.focusLength) < input.focusLength
            let status = pausedMidway
                ? "PAUSED"
                : "SESSION \(state.sessionNumber(of: settings.pomodoroSessionsPerCycle)) OF \(settings.pomodoroSessionsPerCycle)"
            out[out.count - 1].gapAfter = 0.3
            out.append(SceneLine(text: state.phase.boardName + "  " + String(format: "%02d:%02d", seconds / 60, seconds % 60),
                                 weight: 0.42, gapAfter: 0.12))
            out.append(SceneLine(text: "", weight: 0.07, kind: .bar(progress), gapAfter: 0.14))
            out.append(SceneLine(text: status, weight: 0.22, dim: true))
        }

        if settings.showUsageOnWallpaper {
            for provider in UsageProvider.allCases {
                guard let usage = input.usage.providers[provider], let primary = usage.windows.first else { continue }
                let cells = usage.windows.map { "\($0.label) \(Int(($0.remaining * 100).rounded()))%" }
                out[out.count - 1].gapAfter = 0.3
                out.append(SceneLine(text: pad(provider.boardName, 7) + " " + cells.joined(separator: "  "),
                                     weight: 0.26, gapAfter: 0.1))
                out.append(SceneLine(text: "", weight: 0.05, kind: .bar(primary.remaining), gapAfter: 0.1))
            }
        }

        if settings.layout == .map {
            out[out.count - 1].gapAfter = 0.3
            out.append(SceneLine(text: "", weight: 3.4, kind: .map))
        }

        if settings.layout == .board {
            let cities = settings.cities.compactMap(City.find)
            if !cities.isEmpty {
                out[out.count - 1].gapAfter = 0.34
                // The blank colon keeps the header the same width as the times beneath it.
                let timeLabel = "TIME" + String(PixelFont.blankColon)
                out.append(SceneLine(text: row("DESTINATION", "CODE", timeLabel, "DIFF"), weight: 0.3, dim: true))
                for city in cities {
                    let zone = city.timeZone
                    let there = components(date, in: zone)
                    let time = settings.use24Hour
                        ? String(format: "%02d:%02d", there.hour!, there.minute!)
                        : String(format: "%02d:%02d", hour12(there.hour!), there.minute!) + (there.hour! < 12 ? "A" : "P")
                    let offset = (zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)) / 60
                    out.append(SceneLine(text: row(city.name, city.code, time, diffText(minutes: offset)), weight: 0.3))
                }
            }
        }
        return out
    }

    private static func components(_ date: Date, in zone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: date)
    }

    private static func hour12(_ hour: Int) -> Int {
        hour % 12 == 0 ? 12 : hour % 12
    }

    private static func timeText(_ p: DateComponents, settings: AeroSettings, colon: String) -> String {
        let hour = settings.use24Hour ? p.hour! : hour12(p.hour!)
        var text = String(format: "%02d", hour) + colon + String(format: "%02d", p.minute!)
        if settings.showSeconds { text += colon + String(format: "%02d", p.second!) }
        if !settings.use24Hour { text += p.hour! < 12 ? " AM" : " PM" }
        return text
    }

    private static func dateText(_ p: DateComponents, format: DateFormatStyle) -> String {
        let day = String(format: "%02d", p.day!)
        switch format {
        case .weekdayDayMonth: return "\(weekdays[p.weekday! - 1]) \(day) \(months[p.month! - 1])"
        case .dayMonthYear: return "\(day) \(months[p.month! - 1]) \(p.year!)"
        case .full: return "\(weekdaysFull[p.weekday! - 1]) \(day) \(monthsFull[p.month! - 1])"
        case .iso: return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
        }
    }

    private static func diffText(minutes: Int) -> String {
        let sign = minutes < 0 ? "-" : "+"
        let hours = abs(minutes) / 60, rest = abs(minutes) % 60
        return "\(sign)\(hours)H" + (rest == 0 ? "" : String(format: "%02d", rest))
    }

    private static func row(_ city: String, _ code: String, _ time: String, _ diff: String) -> String {
        pad(city, 13) + " " + pad(code, 4) + " " + pad(time, 6) + " " + pad(diff, 5)
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        String(text.prefix(width)).padding(toLength: width, withPad: " ", startingAt: 0)
    }
}
