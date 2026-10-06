// Renders the Aero app icon: a dot-matrix "A" on a black squircle.
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let glyph = [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"].map(Array.init)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
ctx.addPath(squircle)
ctx.setFillColor(CGColor(gray: 0, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// Body gradient
ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let gradient = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0.13, alpha: 1), CGColor(gray: 0.0, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

// Dot matrix: 7 x 9 grid, glyph inset by one dot on every side
let cols = 7, rows = 9
let pitch: CGFloat = 74
let dot = pitch * 0.74
let originX = body.midX - CGFloat(cols) * pitch / 2
let originY = body.midY + CGFloat(rows) * pitch / 2

func dotRect(_ col: Int, _ row: Int) -> CGRect {
    CGRect(x: originX + CGFloat(col) * pitch + (pitch - dot) / 2,
           y: originY - CGFloat(row + 1) * pitch + (pitch - dot) / 2, width: dot, height: dot)
}
func isLit(_ col: Int, _ row: Int) -> Bool {
    (1...5).contains(col) && (1...7).contains(row) && glyph[row - 1][col - 1] == "#"
}

ctx.setFillColor(CGColor(gray: 1, alpha: 0.085))
for row in 0..<rows { for col in 0..<cols where !isLit(col, row) { ctx.fillEllipse(in: dotRect(col, row)) } }

ctx.setShadow(offset: .zero, blur: 34, color: CGColor(gray: 1, alpha: 0.55))
ctx.setFillColor(CGColor(gray: 1, alpha: 1))
for row in 0..<rows { for col in 0..<cols where isLit(col, row) { ctx.fillEllipse(in: dotRect(col, row)) } }
ctx.restoreGState()

// Hairline rim
ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184.5, cornerHeight: 184.5, transform: nil))
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.10))
ctx.setLineWidth(3)
ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
