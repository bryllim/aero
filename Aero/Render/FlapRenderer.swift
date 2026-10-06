import SwiftUI

/// Split-flap tiles. Animation is derived purely from the time since the last
/// second boundary, so nothing has to remember what was on screen before.
enum FlapRenderer {
    // Proportions relative to the tile height.
    private static let tileWidth: CGFloat = 0.66
    private static let gap: CGFloat = 0.07
    private static let separatorWidth: CGFloat = 0.2

    private static let singleFlip: TimeInterval = 0.3
    private static let cycleFlip: TimeInterval = 0.085
    private static let stagger: TimeInterval = 0.014
    private static let maxSteps = 7

    private static let digitWheel = Array("0123456789")
    private static let fullWheel = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-/.")

    private static func isSeparator(_ character: Character) -> Bool {
        character == ":" || character == PixelFont.blankColon
    }

    static func widthUnits(_ text: String) -> CGFloat {
        text.reduce(0) { $0 + (isSeparator($1) ? separatorWidth : tileWidth) } + CGFloat(max(text.count - 1, 0)) * gap
    }

    /// The faces a tile shows on its way from one character to another.
    private static func path(from old: Character, to new: Character) -> [Character] {
        let wheel = old.isNumber && new.isNumber ? digitWheel : fullWheel
        guard let a = wheel.firstIndex(of: old), let b = wheel.firstIndex(of: new) else { return [old, new] }
        let distance = (b - a + wheel.count) % wheel.count
        let steps = min(distance, maxSteps)
        return [old] + (0..<steps).reversed().map { wheel[(b - $0 + wheel.count) % wheel.count] }
    }

    private static func flipTime(steps: Int) -> TimeInterval {
        steps <= 1 ? singleFlip : Double(steps) * cycleFlip
    }

    /// Tiles that differ between two scenes, as (old, new) pairs in drawing order.
    private static func changes(from previous: [SceneLine], to current: [SceneLine]) -> [(Character, Character)] {
        guard previous.count == current.count else { return [] }
        var out: [(Character, Character)] = []
        for (old, new) in zip(previous, current) where old.text.count == new.text.count {
            for (a, b) in zip(old.text, new.text) where a != b && !isSeparator(b) { out.append((a, b)) }
        }
        return out
    }

    /// How long the transition between two scenes animates for; zero if nothing flips.
    static func duration(from previous: [SceneLine], to current: [SceneLine]) -> TimeInterval {
        let changed = changes(from: previous, to: current)
        guard !changed.isEmpty else { return 0 }
        let longest = changed.map { flipTime(steps: path(from: $0.0, to: $0.1).count - 1) }.max() ?? 0
        return min(0.95, longest + Double(changed.count) * stagger + 0.05)
    }

    static func draw(_ context: inout GraphicsContext, frames: [LineFrame], previous: [SceneLine]?,
                     elapsed: TimeInterval, settings: AeroSettings) {
        let foreground = RGB(hex: settings.foregroundHex)
        let background = RGB(hex: settings.backgroundHex)
        let style = TileStyle(top: background.mix(foreground, 0.135).color,
                              bottom: background.mix(foreground, 0.08).color,
                              hinge: background.color,
                              typeface: settings.flapTypeface)
        let comparable = previous?.count == frames.count
        var changedIndex = 0

        for (lineIndex, frame) in frames.enumerated() {
            let height = frame.rect.height
            let ink = foreground.color.opacity(frame.line.dim ? 0.5 : 1)
            var oldCharacters: [Character]?
            if comparable, let old = previous?[lineIndex].text, old.count == frame.line.text.count {
                oldCharacters = Array(old)
            }

            var x = frame.rect.minX
            for (index, character) in frame.line.text.enumerated() {
                if isSeparator(character) {
                    if character == ":" {
                        let side = height * 0.085
                        for fraction in [0.36, 0.64] {
                            let dot = CGRect(x: x + (height * separatorWidth - side) / 2,
                                             y: frame.rect.minY + height * fraction - side / 2, width: side, height: side)
                            context.fill(Path(dot), with: .color(ink))
                        }
                    }
                    x += height * (separatorWidth + gap)
                    continue
                }

                let rect = CGRect(x: x, y: frame.rect.minY, width: height * tileWidth, height: height)
                x += height * (tileWidth + gap)

                guard let old = oldCharacters?[index], old != character else {
                    drawStatic(context, character, in: rect, ink: ink, style: style)
                    continue
                }

                let faces = path(from: old, to: character)
                let steps = faces.count - 1
                let step = steps <= 1 ? singleFlip : cycleFlip
                let time = elapsed - Double(changedIndex) * stagger
                changedIndex += 1

                if time <= 0 {
                    drawStatic(context, old, in: rect, ink: ink, style: style)
                } else if time >= Double(steps) * step {
                    drawStatic(context, character, in: rect, ink: ink, style: style)
                } else {
                    let position = time / step
                    let face = Int(position)
                    drawFlip(context, from: faces[face], to: faces[face + 1], progress: position - Double(face),
                             in: rect, ink: ink, style: style)
                }
            }
        }
    }

    private struct TileStyle {
        var top: Color
        var bottom: Color
        var hinge: Color
        var typeface: FlapTypeface
    }

    private static func drawStatic(_ context: GraphicsContext, _ character: Character, in rect: CGRect,
                                   ink: Color, style: TileStyle) {
        fillTile(context, in: rect, style: style)
        drawGlyph(context, character, in: rect, ink: ink, typeface: style.typeface)
        drawHinge(context, in: rect, style: style)
    }

    private static func drawFlip(_ context: GraphicsContext, from old: Character, to new: Character, progress: Double,
                                 in rect: CGRect, ink: Color, style: TileStyle) {
        // The new face waits behind the top; the old face still rests on the bottom.
        drawHalf(context, new, top: true, scale: 1, shade: 0, in: rect, ink: ink, style: style)
        drawHalf(context, old, top: false, scale: 1, shade: 0, in: rect, ink: ink, style: style)

        let swing = cos(progress * .pi)
        if progress < 0.5 {
            drawHalf(context, old, top: true, scale: swing, shade: (1 - swing) * 0.55, in: rect, ink: ink, style: style)
        } else {
            drawHalf(context, new, top: false, scale: -swing, shade: (1 + swing) * 0.55, in: rect, ink: ink, style: style)
        }
        drawHinge(context, in: rect, style: style)
    }

    private static func drawHalf(_ context: GraphicsContext, _ character: Character, top: Bool, scale: Double,
                                 shade: Double, in rect: CGRect, ink: Color, style: TileStyle) {
        var half = context
        half.translateBy(x: 0, y: rect.midY)
        half.scaleBy(x: 1, y: max(scale, 0.001))
        half.translateBy(x: 0, y: -rect.midY)

        let clip = Path(CGRect(x: rect.minX, y: top ? rect.minY : rect.midY, width: rect.width, height: rect.height / 2))
        half.clip(to: clip)
        fillTile(half, in: rect, style: style)
        drawGlyph(half, character, in: rect, ink: ink, typeface: style.typeface)
        if shade > 0 {
            half.fill(clip, with: .color(.black.opacity(shade)))
        }
    }

    private static func fillTile(_ context: GraphicsContext, in rect: CGRect, style: TileStyle) {
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height * 0.07),
                     with: .linearGradient(Gradient(colors: [style.top, style.bottom]),
                                           startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                           endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
    }

    /// The seam between the two flaps, with a pin notch at each end.
    private static func drawHinge(_ context: GraphicsContext, in rect: CGRect, style: TileStyle) {
        let thickness = max(1, rect.height * 0.016)
        let pin = CGSize(width: rect.height * 0.035, height: rect.height * 0.1)
        var path = Path(CGRect(x: rect.minX, y: rect.midY - thickness / 2, width: rect.width, height: thickness))
        for x in [rect.minX, rect.maxX - pin.width] {
            path.addRect(CGRect(x: x, y: rect.midY - pin.height / 2, width: pin.width, height: pin.height))
        }
        context.fill(path, with: .color(style.hinge))
    }

    private static func drawGlyph(_ context: GraphicsContext, _ character: Character, in rect: CGRect,
                                  ink: Color, typeface: FlapTypeface) {
        guard character != " " else { return }
        switch typeface {
        case .classic:
            let text = Text(String(character))
                .font(.custom("HelveticaNeue-CondensedBold", size: rect.height * 0.78))
                .foregroundColor(ink)
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        case .pixel:
            let glyph = PixelFont.glyph(character)
            let cell = min(rect.width * 0.7 / 5, rect.height * 0.66 / CGFloat(PixelFont.rows))
            let pixel = cell * 0.9
            let originX = rect.midX - CGFloat(glyph[0].count) * cell / 2
            let originY = rect.midY - CGFloat(PixelFont.rows) * cell / 2
            var path = Path()
            for (row, bits) in glyph.enumerated() {
                for (column, on) in bits.enumerated() where on {
                    path.addRect(CGRect(x: originX + CGFloat(column) * cell + (cell - pixel) / 2,
                                        y: originY + CGFloat(row) * cell + (cell - pixel) / 2, width: pixel, height: pixel))
                }
            }
            context.fill(path, with: .color(ink))
        }
    }
}
