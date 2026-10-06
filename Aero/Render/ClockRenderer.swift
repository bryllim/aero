import SwiftUI

struct LineFrame {
    var line: SceneLine
    var rect: CGRect
}

/// Lays the scene out in a canvas and hands it to the renderer for the chosen style.
enum ClockRenderer {
    static func draw(_ context: inout GraphicsContext, size: CGSize, input: FaceInput, date: Date) {
        let settings = input.settings
        let lines = ClockScene.lines(input, at: date)
        let allFrames = layout(lines, in: size, settings: settings)
        context.opacity = settings.brightness

        for frame in allFrames {
            switch frame.line.kind {
            case .map: MapRenderer.draw(&context, in: frame.rect, settings: settings, date: date)
            case .bar(let progress): drawBar(&context, in: frame.rect, progress: progress, settings: settings)
            case .systemStats(let snapshot): SystemStatsRenderer.draw(&context, in: frame.rect, snapshot: snapshot, settings: settings)
            case .text: break
            }
        }
        let frames = allFrames.filter { $0.line.isText }
        switch settings.style {
        case .matrix:
            MatrixRenderer.draw(&context, frames: frames, settings: settings)
        case .flap:
            let now = date.timeIntervalSinceReferenceDate
            let second = now.rounded(.down)
            var previous: [SceneLine]?
            if settings.flapAnimation {
                previous = ClockScene.lines(input, at: Date(timeIntervalSinceReferenceDate: second - 0.5))
                    .filter(\.isText)
            }
            FlapRenderer.draw(&context, frames: frames, previous: previous, elapsed: now - second, settings: settings)
        }
    }

    /// A single row of dots, lit from the left up to `progress`.
    static func drawBar(_ context: inout GraphicsContext, in rect: CGRect, progress: Double, settings: AeroSettings) {
        let count = max(8, Int(rect.width / rect.height))
        let pitch = rect.width / CGFloat(count)
        let dot = min(pitch, rect.height) * settings.dotFill
        let lit = Int((progress * Double(count)).rounded())
        var on = Path(), off = Path()
        for index in 0..<count {
            let dotRect = CGRect(x: rect.minX + CGFloat(index) * pitch + (pitch - dot) / 2,
                                 y: rect.midY - dot / 2, width: dot, height: dot)
            if index < lit {
                settings.dotShape == .round ? on.addEllipse(in: dotRect) : on.addRect(dotRect)
            } else {
                settings.dotShape == .round ? off.addEllipse(in: dotRect) : off.addRect(dotRect)
            }
        }
        let foreground = Color(hex: settings.foregroundHex)
        context.fill(off, with: .color(foreground.opacity(max(settings.ghost * 2, 0.14))))
        context.fill(on, with: .color(foreground))
    }

    /// Width of a line of text per unit of its height.
    static func widthUnits(_ text: String, style: DisplayStyle) -> CGFloat {
        switch style {
        case .matrix: CGFloat(PixelFont.columns(text) + 2) / CGFloat(MatrixRenderer.panelRows)
        case .flap: FlapRenderer.widthUnits(text)
        }
    }

    static func layout(_ lines: [SceneLine], in size: CGSize, settings: AeroSettings) -> [LineFrame] {
        guard !lines.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let totalHeight = lines.reduce(0) { $0 + $1.weight } + lines.dropLast().reduce(0) { $0 + $1.gapAfter }
        let widths = lines.map { line -> CGFloat in
            switch line.kind {
            case .text: line.weight * widthUnits(line.text, style: settings.style)
            case .map: line.weight * WorldMap.aspect
            case .bar: line.weight * 30
            case .systemStats: line.weight * CGFloat(SystemStatsRenderer.metricCount(settings)) * 2.5
            }
        }
        let maxWidth = widths.max() ?? 1

        let margin = min(size.width, size.height) * 0.07
        let area = CGRect(origin: .zero, size: size).insetBy(dx: margin, dy: margin)
        let unit = min(area.width * settings.scale / maxWidth, area.height * settings.scale / totalHeight)

        let block = CGSize(width: maxWidth * unit, height: totalHeight * unit)
        let anchor = settings.anchor.unit
        let origin = CGPoint(x: area.minX + (area.width - block.width) * anchor.x,
                             y: area.minY + (area.height - block.height) * anchor.y)

        var frames: [LineFrame] = []
        var y = origin.y
        for (line, width) in zip(lines, widths) {
            let lineWidth = width * unit
            let x = origin.x + (block.width - lineWidth) * anchor.x
            frames.append(LineFrame(line: line, rect: CGRect(x: x, y: y, width: lineWidth, height: line.weight * unit)))
            y += (line.weight + line.gapAfter) * unit
        }
        return frames
    }
}

/// A continuous LED panel per line: every dot is drawn, lit or not.
enum MatrixRenderer {
    /// Seven glyph rows plus one row of padding above and below.
    static let panelRows = PixelFont.rows + 2

    static func draw(_ context: inout GraphicsContext, frames: [LineFrame], settings: AeroSettings) {
        let foreground = Color(hex: settings.foregroundHex)
        var ghost = Path()

        for frame in frames {
            let pitch = frame.rect.height / CGFloat(panelRows)
            let dot = pitch * settings.dotFill
            let inset = (pitch - dot) / 2
            let bitmap = PixelFont.bitmap(frame.line.text)
            let columns = bitmap[0].count
            var lit = Path()

            for row in 0..<panelRows {
                for column in 0..<(columns + 2) {
                    let on = (1...PixelFont.rows).contains(row) && (1...columns).contains(column)
                        && bitmap[row - 1][column - 1]
                    let rect = CGRect(x: frame.rect.minX + CGFloat(column) * pitch + inset,
                                      y: frame.rect.minY + CGFloat(row) * pitch + inset, width: dot, height: dot)
                    if on {
                        add(rect, to: &lit, shape: settings.dotShape)
                    } else if settings.ghost > 0.001 {
                        add(rect, to: &ghost, shape: settings.dotShape)
                    }
                }
            }

            let shading = GraphicsContext.Shading.color(foreground.opacity(frame.line.dim ? 0.5 : 1))
            if settings.glow > 0.01 {
                var halo = context
                halo.addFilter(.blur(radius: pitch * 1.2 * settings.glow))
                halo.opacity = min(1, 0.35 + settings.glow * 0.6)
                halo.drawLayer { $0.fill(lit, with: shading) }
            }
            context.fill(lit, with: shading)
        }

        context.fill(ghost, with: .color(foreground.opacity(settings.ghost)))
    }

    private static func add(_ rect: CGRect, to path: inout Path, shape: DotShape) {
        switch shape {
        case .round: path.addEllipse(in: rect)
        case .square: path.addRect(rect)
        }
    }
}
