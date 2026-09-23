import SwiftUI

/// §9 job 1 — the muscle map, drawn as a full anatomical mannequin: a shaded
/// athletic body with every muscle outlined as its own organic shape (the
/// look of a professional anatomy chart), and the muscles an item works
/// lit up in red on top — primary solid, secondary and stabilisers fainter
/// (`MuscleRole`). Highlighted muscles always draw last, so a deep muscle
/// (rhomboids under the trapezius) is still visible when it is the target.
/// Colour is never the only channel: the accessibility label names them.
public struct MuscleMapView: View {
    public enum Side: String {
        case front, back
    }

    private let side: Side
    /// Muscle slug -> weight (1.0 primary, 0.5 secondary, lower stabiliser).
    private let weights: [String: Double]
    @Environment(\.colorScheme) private var colorScheme

    public init(side: Side, weights: [String: Double]) {
        self.side = side
        self.weights = weights
    }

    private struct Palette {
        let skinTop: Color
        let skinBottom: Color
        let muscleLight: Color
        let muscleDark: Color
        let stroke: Color
        let detail: Color
    }

    private var palette: Palette {
        colorScheme == .dark
            ? Palette(skinTop: Color(hex: "#4B4B52"), skinBottom: Color(hex: "#39393F"),
                      muscleLight: Color(hex: "#56565D"), muscleDark: Color(hex: "#44444A"),
                      stroke: Color(hex: "#6E6E76"), detail: Color(hex: "#6A6A72"))
            : Palette(skinTop: Color(hex: "#EDE7E1"), skinBottom: Color(hex: "#D8CFC6"),
                      muscleLight: Color(hex: "#E9E1D9"), muscleDark: Color(hex: "#D2C6BA"),
                      stroke: Color(hex: "#B7AA9E"), detail: Color(hex: "#C2B5A9"))
    }

    /// Each drawable target muscle → the strongest weight that maps to it
    /// (non-drawable muscles render through their `renderVia` target).
    private var targetWeights: [String: Double] {
        var result: [String: Double] = [:]
        for (slug, weight) in weights {
            guard let muscle = musclesBySlug[slug] else { continue }
            let target = muscle.drawable ? muscle.id : (muscle.renderVia ?? muscle.id)
            result[target] = max(result[target] ?? 0, weight)
        }
        return result
    }

    public var body: some View {
        let palette = palette
        let highlighted = targetWeights
        let view = side.rawValue
        Canvas { context, size in
            let scale = min(size.width / muscleMapCanonicalWidth, size.height / muscleMapCanonicalHeight)
            let offsetX = (size.width - muscleMapCanonicalWidth * scale) / 2
            let offsetY = (size.height - muscleMapCanonicalHeight * scale) / 2
            let transform = CGAffineTransform(translationX: offsetX, y: offsetY).scaledBy(x: scale, y: scale)

            func shape(_ d: String) -> Path { SVGPathParser.path(from: d).applying(transform) }
            func diagonalGradient(_ path: Path, _ from: Color, _ to: Color) -> GraphicsContext.Shading {
                let box = path.boundingRect
                return .linearGradient(Gradient(colors: [from, to]), startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY))
            }

            // Body and head.
            let outline = shape(anatomyOutlinePath)
            let bodyBox = outline.boundingRect
            let skin = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [palette.skinTop, palette.skinBottom]),
                startPoint: CGPoint(x: bodyBox.midX, y: bodyBox.minY), endPoint: CGPoint(x: bodyBox.midX, y: bodyBox.maxY)
            )
            context.fill(outline, with: skin)
            context.stroke(outline, with: .color(palette.stroke), lineWidth: 0.45 * scale)
            let head = Path(ellipseIn: CGRect(
                x: anatomyHead.cx - anatomyHead.rx, y: anatomyHead.cy - anatomyHead.ry,
                width: anatomyHead.rx * 2, height: anatomyHead.ry * 2
            )).applying(transform)
            context.fill(head, with: skin)
            context.stroke(head, with: .color(palette.stroke), lineWidth: 0.45 * scale)

            // Every muscle of this view, unworked ones first.
            let keys = muscleMapPaths.keys.filter { $0.split(separator: ".").dropFirst().first.map(String.init) == view }.sorted()
            for key in keys {
                let slug = String(key.split(separator: ".").first ?? "")
                guard highlighted[slug] == nil, let d = muscleMapPaths[key] else { continue }
                let path = shape(d)
                context.fill(path, with: diagonalGradient(path, palette.muscleLight, palette.muscleDark))
                context.stroke(path, with: .color(palette.stroke), lineWidth: 0.35 * scale)
            }

            for d in (side == .front ? anatomyDetailPathsFront : anatomyDetailPathsBack) {
                context.stroke(shape(d), with: .color(palette.detail), style: StrokeStyle(lineWidth: 0.3 * scale, lineCap: .round))
            }

            // Soft side shading, clipped to the body, for volume.
            context.drawLayer { layer in
                layer.clip(to: outline)
                layer.fill(Path(bodyBox), with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .black.opacity(0.08), location: 0.25),
                        .init(color: .black.opacity(0), location: 0.5),
                        .init(color: .black.opacity(0.08), location: 0.75),
                    ]),
                    startPoint: CGPoint(x: bodyBox.minX, y: bodyBox.midY), endPoint: CGPoint(x: bodyBox.maxX, y: bodyBox.midY)
                ))
            }

            // Worked muscles, on top.
            let hot = Color(hex: "#F2554F")
            let deep = Color(hex: muscleMapPrimaryColorHex)
            let rim = Color(hex: "#A61E22")
            for key in keys {
                let slug = String(key.split(separator: ".").first ?? "")
                guard let weight = highlighted[slug], let d = muscleMapPaths[key] else { continue }
                let opacity = MuscleRole(weight: weight).opacity
                let path = shape(d)
                context.fill(path, with: diagonalGradient(path, hot.opacity(opacity), deep.opacity(opacity)))
                context.stroke(path, with: .color(rim.opacity(opacity)), lineWidth: 0.4 * scale)
            }
        }
        .aspectRatio(muscleMapCanonicalWidth / muscleMapCanonicalHeight, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let names = weights.keys
            .compactMap { musclesBySlug[$0]?.plainName }
            .sorted()
        return names.isEmpty ? "Muscle map" : "Targets \(names.joined(separator: ", "))"
    }
}

#Preview("Front — soccer instep strike") {
    MuscleMapView(side: .front, weights: [
        "rectus-femoris": 1.0, "gluteus-maximus": 0.6, "tibialis-anterior": 0.4,
    ])
    .padding()
}

#Preview("Back — hinge pattern") {
    MuscleMapView(side: .back, weights: [
        "gluteus-maximus": 1.0, "erector-spinae": 0.7, "biceps-femoris": 1.0,
    ])
    .padding()
}
