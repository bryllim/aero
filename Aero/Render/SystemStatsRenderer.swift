import SwiftUI

/// Unframed system readings, using the wallpaper's existing dot or flap typeface.
enum SystemStatsRenderer {
    private struct Metric {
        var label: String
        var value: String
        var detail: String
        var fraction: Double?
    }

    static func metricCount(_ settings: AeroSettings) -> Int {
        [settings.systemStatsCPU, settings.systemStatsMemory, settings.systemStatsSwap].filter { $0 }.count
    }

    static func draw(_ context: inout GraphicsContext, in rect: CGRect, snapshot: SystemSnapshot, settings: AeroSettings) {
        let metrics = metrics(snapshot, settings: settings)
        guard !metrics.isEmpty else { return }
        let gap = rect.height * 0.12
        let width = (rect.width - gap * CGFloat(metrics.count - 1)) / CGFloat(metrics.count)
        for (index, metric) in metrics.enumerated() {
            let card = CGRect(x: rect.minX + CGFloat(index) * (width + gap), y: rect.minY, width: width, height: rect.height)
            let inset = card.height * 0.13
            let contentWidth = card.width - inset * 2

            text(&context, metric.label, in: CGRect(x: card.minX + inset, y: card.minY + card.height * 0.12,
                                                  width: contentWidth, height: card.height * 0.14), dim: true, settings: settings)
            text(&context, metric.value, in: CGRect(x: card.minX + inset, y: card.minY + card.height * 0.33,
                                                  width: contentWidth, height: card.height * 0.25), dim: false, settings: settings)
            text(&context, metric.detail, in: CGRect(x: card.minX + inset, y: card.minY + card.height * 0.65,
                                                   width: contentWidth, height: card.height * 0.1), dim: true, settings: settings)
            ClockRenderer.drawBar(&context, in: CGRect(x: card.minX + inset, y: card.minY + card.height * 0.84,
                                                      width: contentWidth, height: card.height * 0.035),
                                  progress: metric.fraction ?? 0, settings: settings)
        }
    }

    private static func metrics(_ snapshot: SystemSnapshot, settings: AeroSettings) -> [Metric] {
        var out: [Metric] = []
        if settings.systemStatsCPU {
            out.append(Metric(label: "CPU", value: snapshot.cpuFraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "--",
                              detail: snapshot.cpuFraction == nil ? "SAMPLING" : "ALL CORES", fraction: snapshot.cpuFraction))
        }
        if settings.systemStatsMemory {
            let total = snapshot.physicalMemoryBytes
            out.append(Metric(label: "RAM", value: snapshot.memoryUsedBytes.map { SystemSnapshot.gigabytes($0) + " GB" } ?? "--",
                              detail: "OF " + SystemSnapshot.gigabytes(total) + " GB",
                              fraction: snapshot.memoryUsedBytes.flatMap { total > 0 ? Double($0) / Double(total) : nil }))
        }
        if settings.systemStatsSwap {
            let total = snapshot.swapTotalBytes ?? 0
            out.append(Metric(label: "SWAP", value: snapshot.swapUsedBytes.map { SystemSnapshot.gigabytes($0) + " GB" } ?? "--",
                              detail: total == 0 ? "ON DISK" : "OF " + SystemSnapshot.gigabytes(total) + " GB",
                              fraction: snapshot.swapUsedBytes.map { total > 0 ? Double($0) / Double(total) : 0 }))
        }
        return out
    }

    private static func text(_ context: inout GraphicsContext, _ text: String, in area: CGRect, dim: Bool, settings: AeroSettings) {
        let ratio = ClockRenderer.widthUnits(text, style: settings.style)
        let height = min(area.height, area.width / max(1, ratio))
        let frame = LineFrame(line: SceneLine(text: text, weight: 1, dim: dim),
                              rect: CGRect(x: area.minX, y: area.midY - height / 2, width: ratio * height, height: height))
        switch settings.style {
        case .matrix: MatrixRenderer.draw(&context, frames: [frame], settings: settings)
        case .flap: FlapRenderer.draw(&context, frames: [frame], previous: nil, elapsed: 1, settings: settings)
        }
    }
}
