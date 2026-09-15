import SwiftUI

/// A persistable RGBA color, since SwiftUI's `Color` isn't directly `Codable`.
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Rec. 709 relative luminance, used to auto-pick a readable foreground
    /// color regardless of system light/dark mode.
    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Black or white, whichever contrasts best against this background.
    var contrastingForeground: Color {
        luminance > 0.5 ? .black : .white
    }

    static let `default` = CodableColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        // NSColor bridging to extract components reliably on macOS.
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        self.red = Double(ns.redComponent)
        self.green = Double(ns.greenComponent)
        self.blue = Double(ns.blueComponent)
        self.alpha = Double(ns.alphaComponent)
    }
}
