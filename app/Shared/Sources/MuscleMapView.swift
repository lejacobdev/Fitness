import SwiftUI

/// §9 job 1 — the static muscle map. Draws the body silhouette first, so a
/// coloured patch reads as sitting ON a person rather than floating in empty
/// space next to unrelated shapes, then overlays every muscle the given item
/// actually touches — primary solid, secondary and stabiliser fainter, per
/// `MuscleRole`. Colour is never the only channel (§9): a screen using this
/// view is expected to also list the muscle names in text for VoiceOver,
/// which `accessibilityLabel` here provides as a fallback if it doesn't.
public struct MuscleMapView: View {
    public enum Side: String {
        case front, back
    }

    private let side: Side
    /// Muscle slug -> weight, e.g. an item's own `muscles` dictionary from
    /// the content pack (1.0 primary, 0.5 secondary, lower stabiliser).
    private let weights: [String: Double]

    public init(side: Side, weights: [String: Double]) {
        self.side = side
        self.weights = weights
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width / muscleMapCanonicalWidth, size.height / muscleMapCanonicalHeight)
            let offsetX = (size.width - muscleMapCanonicalWidth * scale) / 2
            let offsetY = (size.height - muscleMapCanonicalHeight * scale) / 2

            var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            transform = transform.scaledBy(x: scale, y: scale)

            let silhouetteFill = GraphicsContext.Shading.color(Color(hex: bodySilhouetteFillHex))
            let silhouetteStroke = GraphicsContext.Shading.color(Color(hex: bodySilhouetteStrokeHex))
            let shapes = side == .front ? bodySilhouetteFront : bodySilhouetteBack
            for shape in shapes {
                let path = SVGPathParser.path(from: shape.d).applying(transform)
                context.fill(path, with: silhouetteFill)
                context.stroke(path, with: silhouetteStroke, lineWidth: 0.4 * scale)
            }

            let accentColor = Color(hex: muscleMapPrimaryColorHex)
            for (slug, weight) in weights {
                guard let muscle = musclesBySlug[slug] else { continue }
                let targetSlug = muscle.drawable ? muscle.id : (muscle.renderVia ?? muscle.id)
                let role = MuscleRole(weight: weight)
                let shading = GraphicsContext.Shading.color(accentColor.opacity(role.opacity))
                for pathSide in ["left", "right"] {
                    // A missing key means this muscle isn't visible from this
                    // side — e.g. a calf muscle has no "front" front key for
                    // some views — so it is simply skipped, not an error.
                    guard let d = muscleMapPaths["\(targetSlug).\(side.rawValue).\(pathSide)"] else { continue }
                    let path = SVGPathParser.path(from: d).applying(transform)
                    context.fill(path, with: shading)
                }
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
        "rectus-femoris": 0.8, "gluteus-maximus": 0.6, "tibialis-anterior": 0.4,
    ])
    .padding()
}

#Preview("Back — hinge pattern") {
    MuscleMapView(side: .back, weights: [
        "gluteus-maximus": 1.0, "erector-spinae": 0.7, "biceps-femoris": 0.8,
    ])
    .padding()
}
