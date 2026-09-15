#!/usr/bin/env swift

// Draws the app icon — a sliced kiwi fruit (the pun in "KeyWii") with a
// tech/circuit accent (two seeds swapped for glowing LEDs, a circuit
// trace arcing across the flesh, and faint PCB traces in the background
// corners), on the same dark rounded-square chrome as the panel itself,
// at every size macOS's .iconset format requires. `iconutil` then
// compiles them into an .icns.
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

    let cx = s * 0.5
    let cy = s * 0.5
    let center = CGPoint(x: cx, y: cy)

    func fillEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) {
        let ellipseRect = CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
        ctx.addEllipse(in: ellipseRect)
    }

    // Fuzzy brown skin: a ring, stippled with small dots (deterministic,
    // sine-jittered rather than random, so the icon renders identically
    // every run) to read as fuzz rather than a flat ring at larger sizes.
    let skinRadius = s * 0.37
    let fleshRadius = s * 0.325
    ctx.setFillColor(CGColor(red: 0.45, green: 0.33, blue: 0.16, alpha: 1.0))
    fillEllipse(center: center, radiusX: skinRadius, radiusY: skinRadius)
    ctx.fillPath()

    let fuzzColor = CGColor(red: 0.58, green: 0.44, blue: 0.24, alpha: 0.8)
    let fuzzRingRadius = (skinRadius + fleshRadius) / 2
    let fuzzDots = 40
    for i in 0..<fuzzDots {
        let angle = (CGFloat(i) / CGFloat(fuzzDots)) * .pi * 2
        let jitter = sin(angle * 7) * (skinRadius - fleshRadius) * 0.18
        let point = CGPoint(
            x: cx + cos(angle) * (fuzzRingRadius + jitter),
            y: cy + sin(angle) * (fuzzRingRadius + jitter)
        )
        ctx.setFillColor(fuzzColor)
        fillEllipse(center: point, radiusX: s * 0.008, radiusY: s * 0.008)
        ctx.fillPath()
    }

    // Bright green flesh, radially shaded so it reads as fruit rather
    // than a flat disc.
    let fleshColors = [
        CGColor(red: 0.72, green: 0.85, blue: 0.32, alpha: 1.0),
        CGColor(red: 0.48, green: 0.68, blue: 0.20, alpha: 1.0),
    ] as CFArray
    ctx.saveGState()
    fillEllipse(center: center, radiusX: fleshRadius, radiusY: fleshRadius)
    ctx.clip()
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: fleshColors, locations: [0, 1]) {
        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: fleshRadius,
            options: []
        )
    }
    ctx.restoreGState()

    // Pale core at the center.
    let coreRadius = s * 0.09
    ctx.setFillColor(CGColor(red: 0.94, green: 0.92, blue: 0.78, alpha: 1.0))
    fillEllipse(center: center, radiusX: coreRadius, radiusY: coreRadius)
    ctx.fillPath()

    // Seeds: a ring of small dark ellipses pointing radially outward from
    // the core, like a real kiwi slice — with two on the horizontal axis
    // swapped for glowing cyan LEDs, the tech half of the pun.
    let seedCount = 14
    let seedRingRadius = (coreRadius + fleshRadius) / 2
    let seedColor = CGColor(red: 0.08, green: 0.06, blue: 0.03, alpha: 1.0)
    let ledColor = CGColor(red: 0.55, green: 0.92, blue: 1.0, alpha: 1.0)
    let ledGlow = CGColor(red: 0.45, green: 0.9, blue: 1.0, alpha: 0.35)

    for i in 0..<seedCount {
        let angle = (CGFloat(i) / CGFloat(seedCount)) * .pi * 2
        let point = CGPoint(x: cx + cos(angle) * seedRingRadius, y: cy + sin(angle) * seedRingRadius)
        let isLED = i == 0 || i == seedCount / 2

        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        ctx.rotate(by: angle)

        if isLED {
            ctx.setFillColor(ledGlow)
            fillEllipse(center: .zero, radiusX: s * 0.028, radiusY: s * 0.028)
            ctx.fillPath()
            ctx.setFillColor(ledColor)
            fillEllipse(center: .zero, radiusX: s * 0.014, radiusY: s * 0.014)
            ctx.fillPath()
        } else {
            ctx.setFillColor(seedColor)
            fillEllipse(center: .zero, radiusX: s * 0.022, radiusY: s * 0.009)
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    // Circuit trace arcing across the flesh, connecting the two LED
    // seeds — the one detail that ties the "tech" half of the name
    // directly onto the fruit itself.
    let ledA = CGPoint(x: cx + seedRingRadius, y: cy)
    let ledB = CGPoint(x: cx - seedRingRadius, y: cy)
    let tracePath = CGMutablePath()
    tracePath.move(to: ledA)
    tracePath.addQuadCurve(to: ledB, control: CGPoint(x: cx, y: cy + seedRingRadius * 1.1))
    ctx.setStrokeColor(CGColor(red: 0.55, green: 0.92, blue: 1.0, alpha: 0.8))
    ctx.setLineWidth(max(1, s * 0.01))
    ctx.setLineCap(.round)
    ctx.addPath(tracePath)
    ctx.strokePath()
    ctx.setFillColor(ledColor)
    fillEllipse(center: CGPoint(x: cx, y: cy + seedRingRadius * 0.85), radiusX: s * 0.012, radiusY: s * 0.012)
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
