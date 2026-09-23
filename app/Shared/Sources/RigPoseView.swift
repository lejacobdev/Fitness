import SwiftUI

/// §9 job 2 — the exercise animation: a 3D athlete performing the item's
/// movement pattern keyframe by keyframe, with planted feet and hands that
/// stay put, the equipment in hand, the bench or bar or bike it uses, and
/// the muscles the item works glowing red on the moving body.
///
/// The maths lives in RigEngine.swift and the drawing in RigShapes.swift;
/// both mirror content/src/rig3d.js and rigDraw.js, which the content tests
/// check for feet on the floor, joints in range and nothing through the floor.
public struct RigPoseView: View {
    private let pattern: PosePatternInfo
    private let muscles: [String: Double]
    private let animated: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(pattern: PosePatternInfo, muscles: [String: Double] = [:], animated: Bool = true) {
        self.pattern = pattern
        self.muscles = muscles
        self.animated = animated
    }

    public var body: some View {
        let playback = RigPlaybackCache.playback(for: pattern)
        let glow = RigMuscleRegion.glow(for: muscles)
        let palette = RigPalette.forScheme(colorScheme)
        let frame = RigFraming.bounds(for: playback)
        let still = !animated || reduceMotion
        TimelineView(.animation(paused: still)) { timeline in
            let t = still
                ? stillPhase(playback)
                : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: playback.cycleSeconds) / playback.cycleSeconds
            let skeleton = still ? playback.keyframe(min(pattern.thumb, pattern.keyframes.count - 1)) : playback.frame(at: t)
            Canvas { context, size in
                RigCanvas.draw(RigShapes.shapes(skeleton, playback: playback, glow: glow, palette: palette), in: &context,
                               size: size, frame: frame, ground: playback.info.fixture?.kind != "water" ? Color(hex: palette.ground) : nil)
            }
        }
        .accessibilityHidden(true) // decorative alongside the item's own text
    }

    private func stillPhase(_ playback: RigPlayback) -> Double { 0 }
}

/// A still frame for list thumbnails — the pattern's most telling keyframe.
struct RigStillView: View {
    let pattern: PosePatternInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let playback = RigPlaybackCache.playback(for: pattern)
        let palette = RigPalette.forScheme(colorScheme)
        let frame = RigFraming.bounds(for: playback)
        let skeleton = playback.keyframe(min(pattern.thumb, pattern.keyframes.count - 1))
        Canvas { context, size in
            RigCanvas.draw(RigShapes.shapes(skeleton, playback: playback, glow: [:], palette: palette), in: &context,
                           size: size, frame: frame, ground: playback.info.fixture?.kind != "water" ? Color(hex: palette.ground) : nil)
        }
        .accessibilityHidden(true)
    }
}

/// One fixed camera box per pattern (sampled over the whole cycle), so the
/// view never jitters or zooms while the athlete moves.
@MainActor
enum RigFraming {
    private static var cache: [String: CGRect] = [:]

    static func bounds(for playback: RigPlayback) -> CGRect {
        if let hit = cache[playback.info.id] { return hit }
        var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
        let palette = RigPalette.forScheme(.light)
        for n in 0..<20 {
            let s = playback.frame(at: Double(n) / 20)
            for shape in RigShapes.shapes(s, playback: playback, glow: [:], palette: palette) where shape.depth > -1e5 {
                for p in shape.points {
                    minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
                }
            }
        }
        let pad = 4.0
        let rect = CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: max(maxY, 2) - minY + pad * 2)
        cache[playback.info.id] = rect
        return rect
    }
}

enum RigCanvas {
    static func draw(_ shapes: [RigShape], in context: inout GraphicsContext, size: CGSize, frame: CGRect, ground: Color?) {
        let scale = min(size.width / frame.width, size.height / frame.height)
        let offsetX = (size.width - frame.width * scale) / 2 - frame.minX * scale
        let offsetY = (size.height - frame.height * scale) / 2 - frame.minY * scale
        let transform = CGAffineTransform(translationX: offsetX, y: offsetY).scaledBy(x: scale, y: scale)
        if let ground {
            var line = Path()
            line.move(to: CGPoint(x: frame.minX, y: 0))
            line.addLine(to: CGPoint(x: frame.maxX, y: 0))
            context.stroke(line.applying(transform), with: .color(ground), lineWidth: 1.2)
        }
        for shape in shapes where shape.points.count >= 2 {
            var path = Path()
            path.addLines(shape.points)
            path.closeSubpath()
            let transformed = path.applying(transform)
            if let width = shape.stroke {
                context.stroke(transformed, with: .color(shape.color.opacity(shape.opacity)), lineWidth: width * scale * 0.5)
            } else {
                context.fill(transformed, with: .color(shape.color.opacity(shape.opacity)))
            }
        }
    }
}

/// Which body region a muscle glows on.
enum RigMuscleRegion: String {
    case thighFront, thighBack, thigh, shinFront, shinBack, chest, abs, upperBack, lowerBack, glutes
    case shoulderCap, upperArmFront, upperArmBack, forearm, neck, foot

    static func region(for muscleRegion: MuscleRegion, slug: String) -> RigMuscleRegion {
        switch slug {
        case "biceps-brachii", "brachialis": return .upperArmFront
        case "triceps-brachii": return .upperArmBack
        case "tibialis-anterior", "peroneals": return .shinFront
        case "gastrocnemius", "soleus": return .shinBack
        case "pectoralis-major", "pectoralis-minor", "serratus-anterior": return .chest
        case "iliopsoas", "tensor-fasciae-latae", "sartorius": return .thighFront
        case "adductors": return .thigh
        default: break
        }
        switch muscleRegion {
        case .neck: return .neck
        case .shoulder: return .shoulderCap
        case .upperBack: return .upperBack
        case .chest: return .chest
        case .lowerBack: return .lowerBack
        case .arm: return .upperArmFront
        case .forearm: return .forearm
        case .trunk: return .abs
        case .hip: return .glutes
        case .quadriceps: return .thighFront
        case .hamstrings: return .thighBack
        case .calf: return .shinBack
        case .foot: return .foot
        }
    }

    /// Region key → strongest role opacity for an item's muscles.
    static func glow(for muscles: [String: Double]) -> [String: Double] {
        var out: [String: Double] = [:]
        for (slug, weight) in muscles {
            guard let info = musclesBySlug[slug] else { continue }
            let key = region(for: info.region, slug: slug).rawValue
            out[key] = max(out[key] ?? 0, MuscleRole(weight: weight).opacity)
        }
        return out
    }
}

#Preview("Back squat") {
    if let pattern = posePatternsBySlug["back-squat"] {
        RigPoseView(pattern: pattern, muscles: ["rectus-femoris": 1, "gluteus-maximus": 1])
            .frame(height: 280)
            .padding()
    }
}

#Preview("Slap shot") {
    if let pattern = posePatternsBySlug["hockey-slap-shot"] {
        RigPoseView(pattern: pattern).frame(height: 280).padding()
    }
}
