import SwiftUI

/// Parses the path strings content/scripts/build.mjs emits (geometry.js's
/// `roundedPolygonToSvgPath` / `polygonToSvgPath`) into a SwiftUI `Path`.
/// Hand-rolled rather than an SVG library (§9: "no SVG library") — the format
/// this project ever emits is a tiny, fixed subset: `M` (move), `L` (line),
/// `Q` (quadratic curve), `C` (cubic curve — the anatomy's splines), `Z`
/// (close); several `M…Z` subpaths may share one string. Works unchanged on watchOS, since it's
/// pure Foundation + SwiftUI, nothing platform-specific.
public enum SVGPathParser {
    public static func path(from data: String) -> Path {
        var path = Path()
        let scanner = Scanner(string: data)
        scanner.charactersToBeSkipped = CharacterSet.whitespaces

        func readDouble() -> Double? {
            scanner.scanDouble()
        }
        func readPoint() -> CGPoint? {
            guard let x = readDouble() else { return nil }
            _ = scanner.scanString(",")
            guard let y = readDouble() else { return nil }
            return CGPoint(x: x, y: y)
        }

        while !scanner.isAtEnd {
            guard let command = scanner.scanCharacter() else { break }
            switch command {
            case "M":
                if let p = readPoint() { path.move(to: p) }
            case "L":
                if let p = readPoint() { path.addLine(to: p) }
            case "Q":
                if let control = readPoint(), let end = readPoint() {
                    path.addQuadCurve(to: end, control: control)
                }
            case "C":
                if let c1 = readPoint(), let c2 = readPoint(), let end = readPoint() {
                    path.addCurve(to: end, control1: c1, control2: c2)
                }
            case "Z":
                path.closeSubpath()
            default:
                continue // unknown command — skip a character and keep scanning
            }
        }
        return path
    }
}

extension Color {
    /// A `#RRGGBB` hex string to Color — the muscle map's fixed palette
    /// (§9's `#E5383B` primary accent, the silhouette's skin tone) is stored
    /// as plain hex strings in generated Swift, not asset-catalog colors,
    /// since it must render identically on watchOS with no catalog to share.
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
