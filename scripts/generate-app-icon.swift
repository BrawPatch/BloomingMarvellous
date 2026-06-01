#!/usr/bin/env swift

// generate-app-icon.swift — renders a 1024×1024 PNG for the Blooming
// Marvellous app icon using Core Graphics. Run from the repo root:
//
//   swift scripts/generate-app-icon.swift
//
// Writes to Assets.xcassets/AppIcon.appiconset/icon-1024.png. The
// design mirrors the in-app brand: a stylised five-petal flower over
// the same mint→sage gradient used by the top banner and the splash
// screen, with a leaf accent and a soft drop shadow.

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let bytesPerRow = Int(size) * 4
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil,
                          width: Int(size),
                          height: Int(size),
                          bitsPerComponent: 8,
                          bytesPerRow: bytesPerRow,
                          space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("Failed to create graphics context\n", stderr)
    exit(1)
}

// Use a coordinate system with origin at top-left so the helpers below
// match the SwiftUI render the icon represents.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// MARK: - Helpers

func hex(_ s: String, alpha: CGFloat = 1) -> CGColor {
    var h = s
    if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt32(h, radix: 16) ?? 0
    let r = CGFloat((v >> 16) & 0xff) / 255
    let g = CGFloat((v >>  8) & 0xff) / 255
    let b = CGFloat( v        & 0xff) / 255
    return CGColor(red: r, green: g, blue: b, alpha: alpha)
}

func filled(_ path: CGPath, _ color: CGColor) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

func stroked(_ path: CGPath, _ color: CGColor, width: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Background (mint → sage gradient, full-bleed)

let bg = CGRect(x: 0, y: 0, width: size, height: size)
let gradient = CGGradient(colorsSpace: space,
                          colors: [hex("#d8f5e8"), hex("#caf0e2"), hex("#a8d8bc")] as CFArray,
                          locations: [0.0, 0.55, 1.0])!
ctx.saveGState()
ctx.addRect(bg)
ctx.clip()
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: 0),
                       end: CGPoint(x: size, y: size),
                       options: [])
ctx.restoreGState()

// MARK: - Soft background flower (lilac)

func petal(centerX: CGFloat, centerY: CGFloat,
           radius: CGFloat,
           angleDeg: CGFloat,
           length: CGFloat,
           width: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let angle = angleDeg * .pi / 180
    let tipX  = centerX + cos(angle) * length
    let tipY  = centerY + sin(angle) * length
    let sideAngle1 = angle + .pi / 2
    let sideAngle2 = angle - .pi / 2
    let baseRightX = centerX + cos(sideAngle1) * width
    let baseRightY = centerY + sin(sideAngle1) * width
    let baseLeftX  = centerX + cos(sideAngle2) * width
    let baseLeftY  = centerY + sin(sideAngle2) * width
    path.move(to: CGPoint(x: baseRightX, y: baseRightY))
    path.addQuadCurve(to: CGPoint(x: tipX, y: tipY),
                      control: CGPoint(x: centerX + cos(angle) * length * 0.7 + cos(sideAngle1) * width * 1.1,
                                       y: centerY + sin(angle) * length * 0.7 + sin(sideAngle1) * width * 1.1))
    path.addQuadCurve(to: CGPoint(x: baseLeftX, y: baseLeftY),
                      control: CGPoint(x: centerX + cos(angle) * length * 0.7 + cos(sideAngle2) * width * 1.1,
                                       y: centerY + sin(angle) * length * 0.7 + sin(sideAngle2) * width * 1.1))
    path.addArc(center: CGPoint(x: centerX, y: centerY),
                radius: radius,
                startAngle: sideAngle2,
                endAngle: sideAngle1,
                clockwise: true)
    path.closeSubpath()
    return path
}

let cx = size / 2
let cy = size / 2 - 30

// Shadow under main flower
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12),
              blur: 28,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))

// MARK: - Main flower (5 petals, peach)

let petalLength: CGFloat = 350
let petalWidth: CGFloat = 105
let petalAngles: [CGFloat] = [90, 90 + 72, 90 + 144, 90 + 216, 90 + 288]

for angle in petalAngles {
    let path = petal(centerX: cx, centerY: cy,
                     radius: 80,
                     angleDeg: angle,
                     length: petalLength,
                     width: petalWidth)
    filled(path, hex("#f0a898"))
    stroked(path, hex("#d68575"), width: 6)
}

// Inner lilac petals (offset rotation)
for angle in petalAngles {
    let path = petal(centerX: cx, centerY: cy,
                     radius: 50,
                     angleDeg: angle + 36,
                     length: 220,
                     width: 65)
    filled(path, hex("#c0a0d8"))
    stroked(path, hex("#9c80b0"), width: 5)
}

// Flower centre
let centreRect = CGRect(x: cx - 95, y: cy - 95, width: 190, height: 190)
filled(CGPath(ellipseIn: centreRect, transform: nil), hex("#e8b070"))
stroked(CGPath(ellipseIn: centreRect, transform: nil), hex("#a87a40"), width: 8)

// Tiny seed dots in the centre
for i in 0..<7 {
    let a = (CGFloat(i) / 7.0) * 2 * .pi
    let r: CGFloat = 45
    let dx = cx + cos(a) * r
    let dy = cy + sin(a) * r
    let dot = CGRect(x: dx - 12, y: dy - 12, width: 24, height: 24)
    filled(CGPath(ellipseIn: dot, transform: nil), hex("#d68f3a"))
}

ctx.restoreGState()

// MARK: - Leaf accent (bottom-left)

func leaf(at center: CGPoint, length: CGFloat, width: CGFloat, angleDeg: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let angle = angleDeg * .pi / 180
    let tipX = center.x + cos(angle) * length / 2
    let tipY = center.y + sin(angle) * length / 2
    let backX = center.x - cos(angle) * length / 2
    let backY = center.y - sin(angle) * length / 2
    let sideA = angle + .pi / 2
    let sideB = angle - .pi / 2
    path.move(to: CGPoint(x: backX, y: backY))
    path.addQuadCurve(to: CGPoint(x: tipX, y: tipY),
                      control: CGPoint(x: center.x + cos(sideA) * width,
                                       y: center.y + sin(sideA) * width))
    path.addQuadCurve(to: CGPoint(x: backX, y: backY),
                      control: CGPoint(x: center.x + cos(sideB) * width,
                                       y: center.y + sin(sideB) * width))
    path.closeSubpath()
    return path
}

let leafPath = leaf(at: CGPoint(x: 230, y: size - 200),
                    length: 280, width: 120, angleDeg: -20)
filled(leafPath, hex("#7aaa8a"))
stroked(leafPath, hex("#4a8a4d"), width: 6)

// Leaf vein
let vein = CGMutablePath()
vein.move(to: CGPoint(x: 100, y: size - 180))
vein.addQuadCurve(to: CGPoint(x: 360, y: size - 220),
                  control: CGPoint(x: 230, y: size - 280))
stroked(vein, hex("#4a8a4d"), width: 5)

// MARK: - Tiny side blossom (top-right)

let sideCx: CGFloat = size - 200
let sideCy: CGFloat = 200
for angle in petalAngles {
    let path = petal(centerX: sideCx, centerY: sideCy,
                     radius: 30,
                     angleDeg: angle,
                     length: 120,
                     width: 40)
    filled(path, hex("#f4b8b0"))
    stroked(path, hex("#c08070"), width: 4)
}
let sideCentre = CGRect(x: sideCx - 30, y: sideCy - 30, width: 60, height: 60)
filled(CGPath(ellipseIn: sideCentre, transform: nil), hex("#b8a0d8"))
stroked(CGPath(ellipseIn: sideCentre, transform: nil), hex("#8a55a3"), width: 4)

// MARK: - Save as PNG

guard let cgImage = ctx.makeImage() else {
    fputs("Failed to make image\n", stderr); exit(1)
}
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr); exit(1)
}
let outPath = "Assets.xcassets/AppIcon.appiconset/icon-1024.png"
let url = URL(fileURLWithPath: outPath)
try! data.write(to: url)
print("✓ Wrote \(outPath) (\(data.count) bytes)")
