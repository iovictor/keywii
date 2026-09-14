#!/usr/bin/env swift

// Draws a simple placeholder app icon — a dark rounded square with a
// stylized split-keyboard glyph (two small clusters of keys, echoing the
// Corne's two halves) — at every size macOS's .iconset format requires,
// then leaves them for `iconutil` to compile into an .icns.
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

    let colors = [
        CGColor(red: 0.20, green: 0.22, blue: 0.29, alpha: 1.0),
        CGColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1.0),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }
    ctx.resetClip()

    // Foreground: two small clusters of rounded-rect "keys", echoing the
    // Corne's split halves, in an accent blue.
    let keyColor = CGColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 1.0)
    let keyDim = CGColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 0.55)
    let keySize = s * 0.14
    let keyGap = s * 0.06
    let keyRadius = keySize * 0.28
    let clusterGap = s * 0.10

    let clusterWidth = keySize * 2 + keyGap
    let clusterHeight = keySize * 2 + keyGap
    let totalWidth = clusterWidth * 2 + clusterGap
    let originX = (s - totalWidth) / 2
    let originY = (s - clusterHeight) / 2

    func drawKey(x: CGFloat, y: CGFloat, color: CGColor) {
        let keyRect = CGRect(x: x, y: y, width: keySize, height: keySize)
        let path = CGPath(roundedRect: keyRect, cornerWidth: keyRadius, cornerHeight: keyRadius, transform: nil)
        ctx.setFillColor(color)
        ctx.addPath(path)
        ctx.fillPath()
    }

    // Left cluster (2x2, brighter accent).
    for row in 0..<2 {
        for col in 0..<2 {
            let x = originX + CGFloat(col) * (keySize + keyGap)
            let y = originY + CGFloat(row) * (keySize + keyGap)
            drawKey(x: x, y: y, color: keyColor)
        }
    }

    // Right cluster (2x2, dimmer accent for depth/variety).
    let rightOriginX = originX + clusterWidth + clusterGap
    for row in 0..<2 {
        for col in 0..<2 {
            let x = rightOriginX + CGFloat(col) * (keySize + keyGap)
            let y = originY + CGFloat(row) * (keySize + keyGap)
            drawKey(x: x, y: y, color: keyDim)
        }
    }

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
