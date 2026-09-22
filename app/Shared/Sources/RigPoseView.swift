import SwiftUI

/// §9 job 2 — the animated pose rig. Separate from MuscleMapView's static
/// figure: this is live forward-kinematics geometry computed from a
/// `[Joint: Double]` angle dictionary at render time, never pre-rendered art.
///
/// A joint's angle is flexion in degrees, relative to its PARENT bone's own
/// direction (0° continues straight from the parent — "fully extended"; a
/// larger angle bends the child bone further toward the front of the body).
/// This is a first-pass, uniform convention applied the same way to every
/// joint rather than a biomechanically distinct rule per joint type (hip
/// flexion and knee flexion bend in anatomically different senses in real
/// life). It renders a consistent, readable stick figure for every one of the
/// 33 pose patterns; the exact degree values authored in poses.js are a first
/// calibration pass, tunable by eye once this is visible on a simulator or
/// device — this file's job is the mechanism, not pixel-perfect motion.
enum RigKinematics {
    // Bone lengths in the same 100x200 canonical space MuscleMapView uses,
    // for consistent sizing if the two are ever shown side by side.
    static let pelvisY: Double = 108
    static let spineLength: Double = 34
    static let neckLength: Double = 12
    static let headRadius: Double = 9
    static let shoulderOffset: Double = 14
    static let hipOffset: Double = 9
    static let upperArmLength: Double = 24
    static let forearmLength: Double = 21
    static let thighLength: Double = 40
    static let shinLength: Double = 37
    static let footLength: Double = 13

    struct Skeleton {
        var pelvis: CGPoint
        var spineTop: CGPoint
        var neckTop: CGPoint
        var shoulderL: CGPoint
        var shoulderR: CGPoint
        var elbowL: CGPoint
        var elbowR: CGPoint
        var wristL: CGPoint
        var wristR: CGPoint
        var hipL: CGPoint
        var hipR: CGPoint
        var kneeL: CGPoint
        var kneeR: CGPoint
        var ankleL: CGPoint
        var ankleR: CGPoint
        var footTipL: CGPoint
        var footTipR: CGPoint
    }

    private static func rotate(_ v: CGVector, degrees: Double) -> CGVector {
        let r = degrees * .pi / 180
        let c = cos(r), s = sin(r)
        return CGVector(dx: v.dx * c - v.dy * s, dy: v.dx * s + v.dy * c)
    }

    private static func add(_ p: CGPoint, _ v: CGVector) -> CGPoint {
        CGPoint(x: p.x + v.dx, y: p.y + v.dy)
    }

    private static func perpendicular(_ v: CGVector) -> CGVector {
        CGVector(dx: -v.dy, dy: v.dx)
    }

    /// Builds the full skeleton for one pose. `mirror` flips left/right
    /// (§7's unilateral expansion rule) without needing a second pose.
    static func skeleton(for pose: [Joint: Double], mirrored: Bool = false) -> Skeleton {
        func angle(_ joint: Joint) -> Double {
            let j = mirrored ? mirror(joint) : joint
            return pose[j] ?? 0
        }

        let pelvis = CGPoint(x: 50, y: pelvisY)
        let up = CGVector(dx: 0, dy: -1)
        let down = CGVector(dx: 0, dy: 1)

        let spineDir = rotate(up, degrees: angle(.spine))
        let spineTop = add(pelvis, CGVector(dx: spineDir.dx * spineLength, dy: spineDir.dy * spineLength))

        let neckDir = rotate(spineDir, degrees: angle(.neck))
        let neckTop = add(spineTop, CGVector(dx: neckDir.dx * neckLength, dy: neckDir.dy * neckLength))

        let acrossShoulders = perpendicular(spineDir)
        let shoulderL = add(spineTop, CGVector(dx: -acrossShoulders.dx * shoulderOffset, dy: -acrossShoulders.dy * shoulderOffset))
        let shoulderR = add(spineTop, CGVector(dx: acrossShoulders.dx * shoulderOffset, dy: acrossShoulders.dy * shoulderOffset))

        let upperArmDirL = rotate(down, degrees: angle(.shoulderL))
        let elbowL = add(shoulderL, CGVector(dx: upperArmDirL.dx * upperArmLength, dy: upperArmDirL.dy * upperArmLength))
        let forearmDirL = rotate(upperArmDirL, degrees: angle(.elbowL))
        let wristL = add(elbowL, CGVector(dx: forearmDirL.dx * forearmLength, dy: forearmDirL.dy * forearmLength))

        let upperArmDirR = rotate(down, degrees: angle(.shoulderR))
        let elbowR = add(shoulderR, CGVector(dx: upperArmDirR.dx * upperArmLength, dy: upperArmDirR.dy * upperArmLength))
        let forearmDirR = rotate(upperArmDirR, degrees: angle(.elbowR))
        let wristR = add(elbowR, CGVector(dx: forearmDirR.dx * forearmLength, dy: forearmDirR.dy * forearmLength))

        let acrossHips = perpendicular(down)
        let hipL = add(pelvis, CGVector(dx: -acrossHips.dx * hipOffset, dy: -acrossHips.dy * hipOffset))
        let hipR = add(pelvis, CGVector(dx: acrossHips.dx * hipOffset, dy: acrossHips.dy * hipOffset))

        let thighDirL = rotate(down, degrees: angle(.hipL))
        let kneeL = add(hipL, CGVector(dx: thighDirL.dx * thighLength, dy: thighDirL.dy * thighLength))
        let shinDirL = rotate(thighDirL, degrees: angle(.kneeL))
        let ankleL = add(kneeL, CGVector(dx: shinDirL.dx * shinLength, dy: shinDirL.dy * shinLength))
        let footDirL = rotate(shinDirL, degrees: angle(.ankleL) - 90)
        let footTipL = add(ankleL, CGVector(dx: footDirL.dx * footLength, dy: footDirL.dy * footLength))

        let thighDirR = rotate(down, degrees: angle(.hipR))
        let kneeR = add(hipR, CGVector(dx: thighDirR.dx * thighLength, dy: thighDirR.dy * thighLength))
        let shinDirR = rotate(thighDirR, degrees: angle(.kneeR))
        let ankleR = add(kneeR, CGVector(dx: shinDirR.dx * shinLength, dy: shinDirR.dy * shinLength))
        let footDirR = rotate(shinDirR, degrees: angle(.ankleR) - 90)
        let footTipR = add(ankleR, CGVector(dx: footDirR.dx * footLength, dy: footDirR.dy * footLength))

        return Skeleton(
            pelvis: pelvis, spineTop: spineTop, neckTop: neckTop,
            shoulderL: shoulderL, shoulderR: shoulderR,
            elbowL: elbowL, elbowR: elbowR, wristL: wristL, wristR: wristR,
            hipL: hipL, hipR: hipR, kneeL: kneeL, kneeR: kneeR,
            ankleL: ankleL, ankleR: ankleR, footTipL: footTipL, footTipR: footTipR
        )
    }

    private static func mirror(_ joint: Joint) -> Joint {
        let name = joint.rawValue
        if name.hasSuffix("L") { return Joint(rawValue: String(name.dropLast()) + "R") ?? joint }
        if name.hasSuffix("R") { return Joint(rawValue: String(name.dropLast()) + "L") ?? joint }
        return joint
    }

    /// Resolves a §9 prop's `attachTo` string (a position name, not
    /// necessarily a `Joint` angle key — e.g. "spine" has no angle of its own
    /// but is a real point on the skeleton) to that skeleton's computed
    /// point. Every `attachTo` value actually used in props.js is covered
    /// here — checked against the generated Props.swift, not assumed.
    static func position(for attachTo: String, in skeleton: Skeleton) -> CGPoint? {
        switch attachTo {
        case "ankleL": return skeleton.ankleL
        case "ankleR": return skeleton.ankleR
        case "wristL": return skeleton.wristL
        case "wristR": return skeleton.wristR
        case "spine": return skeleton.spineTop
        default: return nil
        }
    }
}

/// §9: "a small named shape positioned relative to a joint... around a dozen
/// props cover every sport in the catalogue" — a soccer strike and a hockey
/// shot reuse the same body with a different prop rather than a new rig.
/// Every prop id in the catalogue falls into one of these families by its
/// slug; `implement-throw`, `bat`, `racket` and the two hockey/lacrosse
/// sticks all read naturally as "stick", the two nets as "net".
private func propShape(for prop: PropInfo, at point: CGPoint) -> Path {
    let family: String
    switch prop.id {
    case "ball-round", "ball-oval", "puck": family = "ball"
    case "bar-barbell": family = "bar"
    case "net-goal", "net-court": family = "net"
    case "hurdle": family = "hurdle"
    case "blocks": family = "blocks"
    default: family = "stick"
    }

    var path = Path()
    switch family {
    case "ball":
        let r: Double = prop.id == "puck" ? 2.2 : 3.5
        path.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
    case "bar":
        path.move(to: CGPoint(x: point.x - 22, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 22, y: point.y))
    case "net":
        let rect = CGRect(x: point.x - 12, y: point.y - 14, width: 24, height: 20)
        path.addRect(rect)
    case "hurdle":
        path.move(to: CGPoint(x: point.x - 8, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 8, y: point.y))
        path.move(to: CGPoint(x: point.x - 8, y: point.y))
        path.addLine(to: CGPoint(x: point.x - 8, y: point.y + 10))
        path.move(to: CGPoint(x: point.x + 8, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 8, y: point.y + 10))
    case "blocks":
        path.addRect(CGRect(x: point.x - 6, y: point.y - 3, width: 12, height: 6))
    default: // stick / bat / racket / throwing implement
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x + 4, y: point.y - 18))
    }
    return path
}

/// Draws one static skeleton as uniform-stroke line art (§9) — the shared
/// rendering both frames of the crossfade use.
struct RigSkeletonShape: View {
    let skeleton: RigKinematics.Skeleton
    var prop: PropInfo?

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / muscleMapCanonicalWidth, size.height / muscleMapCanonicalHeight)
            let offsetX = (size.width - muscleMapCanonicalWidth * scale) / 2
            let offsetY = (size.height - muscleMapCanonicalHeight * scale) / 2
            var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            transform = transform.scaledBy(x: scale, y: scale)

            func line(_ a: CGPoint, _ b: CGPoint) {
                var p = Path()
                p.move(to: a)
                p.addLine(to: b)
                context.stroke(p.applying(transform), with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            let s = skeleton
            line(s.pelvis, s.spineTop)
            line(s.spineTop, s.neckTop)
            line(s.spineTop, s.shoulderL)
            line(s.spineTop, s.shoulderR)
            line(s.shoulderL, s.elbowL)
            line(s.elbowL, s.wristL)
            line(s.shoulderR, s.elbowR)
            line(s.elbowR, s.wristR)
            line(s.pelvis, s.hipL)
            line(s.pelvis, s.hipR)
            line(s.hipL, s.kneeL)
            line(s.kneeL, s.ankleL)
            line(s.ankleL, s.footTipL)
            line(s.hipR, s.kneeR)
            line(s.kneeR, s.ankleR)
            line(s.ankleR, s.footTipR)

            let headCenter = CGPoint(x: s.neckTop.x, y: s.neckTop.y - RigKinematics.headRadius)
            let headRect = CGRect(
                x: headCenter.x - RigKinematics.headRadius, y: headCenter.y - RigKinematics.headRadius,
                width: RigKinematics.headRadius * 2, height: RigKinematics.headRadius * 2
            )
            context.stroke(Path(ellipseIn: headRect).applying(transform), with: .color(.primary), style: StrokeStyle(lineWidth: 3))

            if let prop, let anchor = RigKinematics.position(for: prop.attachTo, in: s) {
                let point = CGPoint(x: anchor.x + prop.offsetX, y: anchor.y + prop.offsetY)
                let shape = propShape(for: prop, at: point).applying(transform)
                context.stroke(shape, with: .color(Color(hex: muscleMapPrimaryColorHex)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
        .aspectRatio(muscleMapCanonicalWidth / muscleMapCanonicalHeight, contentMode: .fit)
    }
}

/// §9: "'Animation' is a crossfade. Looping between the start and end pose
/// over about 1.2 seconds reads as movement and costs nothing beyond the two
/// poses each item already has." A literal opacity cross-dissolve between two
/// static renders — not per-frame joint interpolation — which is cheaper and
/// is what the plan specifically asks for.
public struct RigPoseView: View {
    private let start: [Joint: Double]
    private let end: [Joint: Double]
    private let mirrored: Bool
    private let prop: PropInfo?
    @State private var showingEnd = false

    public init(start: [Joint: Double], end: [Joint: Double], mirrored: Bool = false, prop: PropInfo? = nil) {
        self.start = start
        self.end = end
        self.mirrored = mirrored
        self.prop = prop
    }

    public var body: some View {
        ZStack {
            RigSkeletonShape(skeleton: RigKinematics.skeleton(for: start, mirrored: mirrored), prop: prop)
                .opacity(showingEnd ? 0 : 1)
            RigSkeletonShape(skeleton: RigKinematics.skeleton(for: end, mirrored: mirrored), prop: prop)
                .opacity(showingEnd ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                showingEnd = true
            }
        }
        .accessibilityHidden(true) // decorative alongside the item's own text cues
    }
}

/// Convenience initializer from a content-pack pose pattern's plain
/// `[String: Double]` dictionaries (as decoded from JSON), converting keys to
/// `Joint` and dropping anything unrecognized rather than crashing on a
/// pack authored against a newer pose model.
public extension RigPoseView {
    init(startRaw: [String: Double], endRaw: [String: Double], mirrored: Bool = false, prop: PropInfo? = nil) {
        func convert(_ raw: [String: Double]) -> [Joint: Double] {
            Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                Joint(rawValue: key).map { ($0, value) }
            })
        }
        self.init(start: convert(startRaw), end: convert(endRaw), mirrored: mirrored, prop: prop)
    }
}

#Preview("Squat") {
    let pattern = posePatternsBySlug["squat"]!
    return RigPoseView(start: pattern.start, end: pattern.end)
        .padding()
}

#Preview("Lunge, mirrored") {
    let pattern = posePatternsBySlug["lunge"]!
    return RigPoseView(start: pattern.start, end: pattern.end, mirrored: true)
        .padding()
}

#Preview("Instep strike with ball") {
    let pattern = posePatternsBySlug["instep-strike"]!
    return RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["ball-round"])
        .padding()
}

#Preview("Wrist shot with puck") {
    let pattern = posePatternsBySlug["rotational-throw"]!
    return RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["puck"])
        .padding()
}

#Preview("Deadlift with barbell") {
    let pattern = posePatternsBySlug["hinge"]!
    return RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["bar-barbell"])
        .padding()
}

#Preview("Approach with net") {
    let pattern = posePatternsBySlug["vertical-jump"]!
    return RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["net-goal"])
        .padding()
}
