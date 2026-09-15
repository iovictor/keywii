#!/usr/bin/env swift

// Draws the app icon — a stylized kiwi bird (a play on "KeyWii") with a
// tech/circuit accent (a glowing LED eye, a circuit trace along its back,
// and faint PCB traces in the background corners), on the same dark
// rounded-square chrome as the panel itself, at every size macOS's
// .iconset format requires. `iconutil` then compiles them into an .icns.
//
// Run via `swift Scripts/generate_icon.swift`, then:
//   iconutil -c icns Scripts/AppIcon.iconset -o Resources/AppIcon.icns

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let outputDir = URL(fileURLWithPath: "Scripts/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func draw(size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let s = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Background: dark rounded square, matching the panel's own dark chrome.
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.20, green: 0.22, blue: 0.29, alpha: 1.0),
        CGColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1.0),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    }

    let circuitColor = CGColor(red: 0.40, green: 0.85, blue: 0.95, alpha: 0.35)

    // Faint PCB-style traces in two corners — right-angle lines with a
    // small square pad at each end — just enough to read as "circuit"
    // without competing with the bird for attention.
    func drawTrace(from start: CGPoint, corner: CGPoint, end: CGPoint) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: corner)
        path.addLine(to: end)
        ctx.setStrokeColor(circuitColor)
        ctx.setLineWidth(max(1, s * 0.008))
        ctx.addPath(path)
        ctx.strokePath()

        let pad = s * 0.018
        for point in [start, end] {
            ctx.setFillColor(circuitColor)
            ctx.fill(CGRect(x: point.x - pad / 2, y: point.y - pad / 2, width: pad, height: pad))
        }
    }
    drawTrace(
        from: CGPoint(x: s * 0.12, y: s * 0.90),
        corner: CGPoint(x: s * 0.12, y: s * 0.80),
        end: CGPoint(x: s * 0.22, y: s * 0.80)
    )
    drawTrace(
        from: CGPoint(x: s * 0.88, y: s * 0.14),
        corner: CGPoint(x: s * 0.88, y: s * 0.24),
        end: CGPoint(x: s * 0.76, y: s * 0.24)
    )

    ctx.resetClip()
    ctx.addPath(bgPath)
    ctx.clip()

    // Kiwi body: two overlapping filled ellipses (a rounder lower body,
    // a smaller head at the upper-left) painted the same color so they
    // read as one continuous silhouette with no visible seam.
    let cx = s * 0.52
    let bodyCenter = CGPoint(x: cx, y: s * 0.42)
    let bodyRadiusX = s * 0.24
    let bodyRadiusY = s * 0.27
    let headCenter = CGPoint(x: cx - bodyRadiusX * 0.55, y: s * 0.66)
    let headRadius = s * 0.115

    let bodyColors = [
        CGColor(red: 0.78, green: 0.52, blue: 0.28, alpha: 1.0),
        CGColor(red: 0.58, green: 0.36, blue: 0.18, alpha: 1.0),
    ] as CFArray

    func fillEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) {
        let ellipseRect = CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
        ctx.addEllipse(in: ellipseRect)
    }

    ctx.saveGState()
    let bodyPath = CGMutablePath()
    bodyPath.addEllipse(in: CGRect(x: bodyCenter.x - bodyRadiusX, y: bodyCenter.y - bodyRadiusY, width: bodyRadiusX * 2, height: bodyRadiusY * 2))
    bodyPath.addEllipse(in: CGRect(x: headCenter.x - headRadius, y: headCenter.y - headRadius, width: headRadius * 2, height: headRadius * 2))
    ctx.addPath(bodyPath)
    ctx.clip()
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bodyColors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: cx, y: s * 0.78),
            end: CGPoint(x: cx, y: s * 0.16),
            options: []
        )
    }
    ctx.restoreGState()

    // Beak: a thin tapered sliver extending forward from the head.
    let beakBaseTop = CGPoint(x: headCenter.x - headRadius * 0.3, y: headCenter.y + headRadius * 0.35)
    let beakBaseBottom = CGPoint(x: headCenter.x - headRadius * 0.3, y: headCenter.y - headRadius * 0.25)
    let beakTip = CGPoint(x: headCenter.x - bodyRadiusX * 1.55, y: headCenter.y - headRadius * 0.05)
    let beakPath = CGMutablePath()
    beakPath.move(to: beakBaseTop)
    beakPath.addLine(to: beakTip)
    beakPath.addLine(to: beakBaseBottom)
    beakPath.closeSubpath()
    ctx.setFillColor(CGColor(red: 0.42, green: 0.26, blue: 0.14, alpha: 1.0))
    ctx.addPath(beakPath)
    ctx.fillPath()

    // Legs: short dark lines with tiny oval feet.
    let legColor = CGColor(red: 0.32, green: 0.20, blue: 0.11, alpha: 1.0)
    ctx.setStrokeColor(legColor)
    ctx.setLineWidth(s * 0.03)
    ctx.setLineCap(.round)
    for legX in [cx - bodyRadiusX * 0.35, cx + bodyRadiusX * 0.45] {
        let top = CGPoint(x: legX, y: bodyCenter.y - bodyRadiusY * 0.75)
        let bottom = CGPoint(x: legX, y: bodyCenter.y - bodyRadiusY * 1.05)
        ctx.move(to: top)
        ctx.addLine(to: bottom)
        ctx.strokePath()
        ctx.setFillColor(legColor)
        fillEllipse(center: CGPoint(x: legX + s * 0.02, y: bottom.y - s * 0.005), radiusX: s * 0.03, radiusY: s * 0.014)
        ctx.fillPath()
    }

    // Circuit trace along the back: a thin glowing line with two small
    // nodes, tracing the body's upper curve — the one detail that ties
    // the "tech" half of the name directly onto the bird itself.
    let tracePath = CGMutablePath()
    tracePath.move(to: CGPoint(x: cx - bodyRadiusX * 0.7, y: bodyCenter.y + bodyRadiusY * 0.55))
    tracePath.addQuadCurve(
        to: CGPoint(x: cx + bodyRadiusX * 0.75, y: bodyCenter.y + bodyRadiusY * 0.35),
        control: CGPoint(x: cx + bodyRadiusX * 0.1, y: bodyCenter.y + bodyRadiusY * 0.95)
    )
    ctx.setStrokeColor(CGColor(red: 0.55, green: 0.92, blue: 1.0, alpha: 0.85))
    ctx.setLineWidth(max(1, s * 0.012))
    ctx.setLineCap(.round)
    ctx.addPath(tracePath)
    ctx.strokePath()
    for point in [
        CGPoint(x: cx - bodyRadiusX * 0.7, y: bodyCenter.y + bodyRadiusY * 0.55),
        CGPoint(x: cx + bodyRadiusX * 0.2, y: bodyCenter.y + bodyRadiusY * 0.78),
        CGPoint(x: cx + bodyRadiusX * 0.75, y: bodyCenter.y + bodyRadiusY * 0.35),
    ] {
        ctx.setFillColor(CGColor(red: 0.55, green: 0.92, blue: 1.0, alpha: 0.95))
        fillEllipse(center: point, radiusX: s * 0.018, radiusY: s * 0.018)
        ctx.fillPath()
    }

    // LED eye: a small glowing cyan dot instead of a plain bead — the
    // other half of the tech accent.
    let eyeCenter = CGPoint(x: headCenter.x + headRadius * 0.15, y: headCenter.y + headRadius * 0.1)
    ctx.setFillColor(CGColor(red: 0.45, green: 0.9, blue: 1.0, alpha: 0.35))
    fillEllipse(center: eyeCenter, radiusX: headRadius * 0.42, radiusY: headRadius * 0.42)
    ctx.fillPath()
    ctx.setFillColor(CGColor(red: 0.65, green: 0.97, blue: 1.0, alpha: 1.0))
    fillEllipse(center: eyeCenter, radiusX: headRadius * 0.22, radiusY: headRadius * 0.22)
    ctx.fillPath()

    return ctx.makeImage()
}

for (name, pixels) in sizes {
    guard let image = draw(size: pixels) else {
        FileHandle.standardError.write("Failed to render \(name)\n".data(using: .utf8)!)
        continue
    }
    let url = outputDir.appendingPathComponent("\(name).png")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        continue
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Wrote \(url.path)")
}
