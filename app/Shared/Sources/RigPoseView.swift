import SwiftUI

/// §9 job 2 — the exercise animation. A side-view athlete (facing right)
/// whose joints are driven every frame from the item's two authored poses,
/// eased back and forth, rather than two frozen stick figures crossfading.
/// The body is drawn from shapes — a profiled torso, tapered limbs, shirt,
/// shorts and shoes, the far side shaded darker — and the muscles the item
/// works glow red on the moving body.
///
/// Angle conventions are documented in content/src/poses.js and mirrored
/// exactly by content/tools/rigModel.mjs (the preview renderer).
enum RigKinematics {
    static let torso: Double = 42
    static let neck: Double = 7
    static let headRx: Double = 8.4
    static let headRy: Double = 10
    static let upperArm: Double = 27
    static let forearm: Double = 24
    static let hand: Double = 8
    static let thigh: Double = 40
    static let shin: Double = 39
    static let foot: Double = 15
    static let heel: Double = 3.5

    struct Limb {
        var armDir: CGVector
        var elbow: CGPoint
        var foreDir: CGVector
        var wrist: CGPoint
        var handDir: CGVector
        var handTip: CGPoint
        var thighDir: CGVector
        var knee: CGPoint
        var shinDir: CGVector
        var ankle: CGPoint
        var footDir: CGVector
        var toe: CGPoint
        var heel: CGPoint
    }

    struct Skeleton {
        var pelvis: CGPoint
        var torsoDir: CGVector
        var shoulder: CGPoint
        var neckDir: CGVector
        var neckTop: CGPoint
        var headCenter: CGPoint
        var near: Limb
        var far: Limb

        var points: [CGPoint] {
            var pts = [pelvis, shoulder, neckTop, CGPoint(x: headCenter.x, y: headCenter.y - RigKinematics.headRy)]
            for l in [near, far] {
                pts += [l.elbow, l.wrist, l.handTip, l.knee, l.ankle, l.toe, l.heel]
            }
            return pts
        }

        func translated(by v: CGVector) -> Skeleton {
            func t(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + v.dx, y: p.y + v.dy) }
            func limb(_ l: Limb) -> Limb {
                var l = l
                l.elbow = t(l.elbow); l.wrist = t(l.wrist); l.handTip = t(l.handTip)
                l.knee = t(l.knee); l.ankle = t(l.ankle); l.toe = t(l.toe); l.heel = t(l.heel)
                return l
            }
            return Skeleton(pelvis: t(pelvis), torsoDir: torsoDir, shoulder: t(shoulder), neckDir: neckDir,
                            neckTop: t(neckTop), headCenter: t(headCenter), near: limb(near), far: limb(far))
        }
    }

    static func rotate(_ v: CGVector, _ degrees: Double) -> CGVector {
        let r = degrees * .pi / 180
        return CGVector(dx: v.dx * cos(r) - v.dy * sin(r), dy: v.dx * sin(r) + v.dy * cos(r))
    }

    static func add(_ p: CGPoint, _ v: CGVector, _ k: Double = 1) -> CGPoint {
        CGPoint(x: p.x + v.dx * k, y: p.y + v.dy * k)
    }

    static func negate(_ v: CGVector) -> CGVector { CGVector(dx: -v.dx, dy: -v.dy) }

    /// Ground is y = 0: the lowest point of the body touches it, raised by `lift`.
    static func skeleton(for pose: [Joint: Double], mirrored: Bool = false) -> Skeleton {
        func a(_ joint: Joint) -> Double {
            pose[mirrored ? mirror(joint) : joint] ?? 0
        }
        let up = CGVector(dx: 0, dy: -1)
        let pelvis = CGPoint.zero
        let torsoDir = rotate(up, a(.spine))
        let shoulder = add(pelvis, torsoDir, torso)
        let neckDir = rotate(torsoDir, a(.neck))
        let neckTop = add(shoulder, neckDir, neck)
        let headCenter = add(neckTop, neckDir, headRy * 0.85)

        func limb(shoulderJ: Joint, elbowJ: Joint, wristJ: Joint, hipJ: Joint, kneeJ: Joint, ankleJ: Joint) -> Limb {
            let armDir = rotate(negate(torsoDir), -a(shoulderJ))
            let elbow = add(shoulder, armDir, upperArm)
            let foreDir = rotate(armDir, -a(elbowJ))
            let wrist = add(elbow, foreDir, forearm)
            let handDir = rotate(foreDir, -a(wristJ))
            let handTip = add(wrist, handDir, hand)
            let thighDir = rotate(negate(torsoDir), -a(hipJ))
            let knee = add(pelvis, thighDir, thigh)
            let shinDir = rotate(thighDir, a(kneeJ))
            let ankle = add(knee, shinDir, shin)
            let footDir = rotate(shinDir, -(90 + a(ankleJ)))
            return Limb(
                armDir: armDir, elbow: elbow, foreDir: foreDir, wrist: wrist, handDir: handDir, handTip: handTip,
                thighDir: thighDir, knee: knee, shinDir: shinDir, ankle: ankle, footDir: footDir,
                toe: add(ankle, footDir, foot), heel: add(ankle, footDir, -heel)
            )
        }

        let raw = Skeleton(
            pelvis: pelvis, torsoDir: torsoDir, shoulder: shoulder, neckDir: neckDir, neckTop: neckTop, headCenter: headCenter,
            near: limb(shoulderJ: .shoulderL, elbowJ: .elbowL, wristJ: .wristL, hipJ: .hipL, kneeJ: .kneeL, ankleJ: .ankleL),
            far: limb(shoulderJ: .shoulderR, elbowJ: .elbowR, wristJ: .wristR, hipJ: .hipR, kneeJ: .kneeR, ankleJ: .ankleR)
        )
        let lowest = raw.points.map(\.y).max() ?? 0
        return raw.translated(by: CGVector(dx: 0, dy: -lowest - a(.lift)))
    }

    static func interpolate(_ start: [Joint: Double], _ end: [Joint: Double], _ t: Double) -> [Joint: Double] {
        var out: [Joint: Double] = [:]
        for joint in Joint.allCases {
            let s = start[joint] ?? 0
            out[joint] = s + ((end[joint] ?? 0) - s) * t
        }
        return out
    }

    private static func mirror(_ joint: Joint) -> Joint {
        let name = joint.rawValue
        if name.hasSuffix("L") { return Joint(rawValue: String(name.dropLast()) + "R") ?? joint }
        if name.hasSuffix("R") { return Joint(rawValue: String(name.dropLast()) + "L") ?? joint }
        return joint
    }

    /// Where a §9 prop's `attachTo` sits on this skeleton.
    static func position(for attachTo: String, in s: Skeleton) -> CGPoint? {
        switch attachTo {
        case "ankleL": return s.near.ankle
        case "ankleR": return s.far.ankle
        case "wristL": return s.near.wrist
        case "wristR": return s.far.wrist
        case "spine": return s.shoulder
        default: return nil
        }
    }
}

/// Which part of the body a muscle glows on, in side view.
enum RigMuscleRegion {
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
}

/// Draws one frame of the athlete into a GraphicsContext.
struct RigRenderer {
    struct Palette {
        var skinNear, skinFar, shirtNear, shirtFar, shortsNear, shortsFar, shoe, hair, ear, ground: Color

        static func forScheme(_ scheme: ColorScheme) -> Palette {
            let dark = scheme == .dark
            return Palette(
                skinNear: Color(hex: "#D9A47A"), skinFar: Color(hex: "#B07C56"),
                shirtNear: Color(hex: dark ? "#5C6272" : "#2B2D33"), shirtFar: Color(hex: dark ? "#474C59" : "#1D1F24"),
                shortsNear: Color(hex: dark ? "#707688" : "#3A3F4A"), shortsFar: Color(hex: dark ? "#585D6C" : "#2A2E37"),
                shoe: Color(hex: dark ? "#E8E8EC" : "#15161A"), hair: Color(hex: "#2A1D15"), ear: Color(hex: "#C48D63"),
                ground: Color(hex: dark ? "#3A3A40" : "#E3E3E8")
            )
        }
    }

    let skeleton: RigKinematics.Skeleton
    let palette: Palette
    /// Region → strongest role opacity.
    let glow: [RigMuscleRegion: Double]
    let prop: PropInfo?

    typealias K = RigKinematics

    private static func capsule(_ a: CGPoint, _ b: CGPoint, _ ra: Double, _ rb: Double) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.001)
        let n = CGVector(dx: -dy / len, dy: dx / len)
        var p = Path()
        p.move(to: K.add(a, n, ra))
        p.addLine(to: K.add(b, n, rb))
        p.addLine(to: K.add(b, n, -rb))
        p.addLine(to: K.add(a, n, -ra))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: a.x - ra, y: a.y - ra, width: ra * 2, height: ra * 2))
        p.addEllipse(in: CGRect(x: b.x - rb, y: b.y - rb, width: rb * 2, height: rb * 2))
        return p
    }

    /// The half of a limb segment on one side of its axis (front = +1).
    private static func halfCapsule(_ a: CGPoint, _ b: CGPoint, _ ra: Double, _ rb: Double, front: Bool, axis: CGVector) -> Path {
        let side = K.rotate(axis, -90)
        let k: Double = front ? 1 : -1
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        p.addLine(to: K.add(b, side, rb * k))
        p.addLine(to: K.add(a, side, ra * k))
        p.closeSubpath()
        return p
    }

    private static func ellipse(center: CGPoint, rx: Double, ry: Double, along dir: CGVector) -> Path {
        let angle = atan2(dir.dy, dir.dx) - .pi / 2
        let rect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
        let transform = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        return Path(ellipseIn: rect).applying(transform)
    }

    private static let torsoFront: [(Double, Double)] = [(0, 8.6), (0.18, 9.4), (0.45, 8.2), (0.72, 10.6), (0.9, 9.2), (1, 5.6)]
    private static let torsoBack: [(Double, Double)] = [(0, 10.4), (0.15, 8.6), (0.45, 7.6), (0.7, 9.2), (0.9, 9.6), (1, 6.2)]

    private func torsoPoint(_ t: Double, _ offset: Double) -> CGPoint {
        let fwd = K.rotate(skeleton.torsoDir, 90)
        return K.add(K.add(skeleton.pelvis, skeleton.torsoDir, K.torso * t), fwd, offset)
    }

    private func torsoPath() -> Path {
        let pts = Self.torsoFront.map { torsoPoint($0.0, $0.1) } + Self.torsoBack.reversed().map { torsoPoint($0.0, -$0.1) }
        return Self.spline(pts)
    }

    /// Closed Catmull-Rom spline (matches rigModel.mjs's `spline`).
    private static func spline(_ pts: [CGPoint]) -> Path {
        var path = Path()
        let n = pts.count
        guard n > 2 else { return path }
        func p(_ i: Int) -> CGPoint { pts[(i % n + n) % n] }
        path.move(to: p(0))
        for i in 0..<n {
            let p0 = p(i - 1), p1 = p(i), p2 = p(i + 1), p3 = p(i + 2)
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    /// The torso band between two fractions along its length, on one side.
    private func torsoBand(_ t0: Double, _ t1: Double, front: Bool) -> Path {
        let profile = front ? Self.torsoFront : Self.torsoBack
        func offset(_ t: Double) -> Double {
            for i in 0..<(profile.count - 1) where t >= profile[i].0 && t <= profile[i + 1].0 {
                let f = (t - profile[i].0) / (profile[i + 1].0 - profile[i].0)
                return profile[i].1 + (profile[i + 1].1 - profile[i].1) * f
            }
            return profile.last?.1 ?? 8
        }
        let k: Double = front ? 1 : -1
        var path = Path()
        let steps = 6
        path.move(to: torsoPoint(t0, 0))
        for s in 0...steps {
            let t = t0 + (t1 - t0) * Double(s) / Double(steps)
            path.addLine(to: torsoPoint(t, offset(t) * k))
        }
        path.addLine(to: torsoPoint(t1, 0))
        path.closeSubpath()
        return path
    }

    func draw(in context: inout GraphicsContext, transform: CGAffineTransform) {
        func fill(_ path: Path, _ color: Color) {
            context.fill(path.applying(transform), with: .color(color))
        }
        let red = Color(hex: muscleMapPrimaryColorHex)
        func glowFill(_ region: RigMuscleRegion, _ path: Path) {
            guard let opacity = glow[region] else { return }
            context.fill(path.applying(transform), with: .color(red.opacity(0.85 * opacity)))
        }

        // Ground shadow.
        let feetX = [skeleton.near.toe.x, skeleton.near.heel.x, skeleton.far.toe.x, skeleton.far.heel.x, skeleton.pelvis.x]
        let shadowRect = CGRect(x: (feetX.min() ?? 0) - 6, y: -2.2, width: (feetX.max() ?? 0) - (feetX.min() ?? 0) + 12, height: 4.4)
        fill(Path(ellipseIn: shadowRect), .black.opacity(0.12))

        drawLeg(skeleton.far, near: false, fill: fill, glowFill: glowFill)
        drawArm(skeleton.far, near: false, fill: fill, glowFill: glowFill)

        // Neck and head.
        let neck = Self.capsule(skeleton.shoulder, skeleton.neckTop, 4.3, 4)
        fill(neck, palette.skinNear)
        glowFill(.neck, neck)
        let head = Self.ellipse(center: skeleton.headCenter, rx: K.headRx, ry: K.headRy, along: skeleton.neckDir)
        fill(head, palette.skinNear)
        fill(hairPath(), palette.hair)
        let earCenter = K.add(skeleton.headCenter, K.rotate(skeleton.neckDir, 90), -K.headRx * 0.18)
        fill(Self.ellipse(center: earCenter, rx: 1.7, ry: 2.6, along: skeleton.neckDir), palette.ear)

        drawLeg(skeleton.near, near: true, fill: fill, glowFill: glowFill)

        // Torso: shirt, then shorts over the hips.
        fill(torsoPath(), palette.shirtNear)
        glowFill(.chest, torsoBand(0.6, 0.95, front: true))
        glowFill(.abs, torsoBand(0.15, 0.6, front: true))
        glowFill(.upperBack, torsoBand(0.5, 0.97, front: false))
        glowFill(.lowerBack, torsoBand(0.15, 0.52, front: false))
        let shortsTop = K.add(skeleton.pelvis, skeleton.torsoDir, K.torso * 0.16)
        fill(Self.capsule(skeleton.pelvis, shortsTop, 10.2, 9), palette.shortsNear)
        glowFill(.glutes, torsoBand(0, 0.22, front: false))

        drawArm(skeleton.near, near: true, fill: fill, glowFill: glowFill)

        if let prop, let anchor = K.position(for: prop.attachTo, in: skeleton) {
            let point = CGPoint(x: anchor.x + prop.offsetX, y: anchor.y + prop.offsetY)
            context.stroke(propShape(for: prop, at: point).applying(transform), with: .color(red),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
    }

    private func hairPath() -> Path {
        let up = skeleton.neckDir
        let fwd = K.rotate(skeleton.neckDir, 90)
        func onHead(_ phi: Double, _ k: Double, _ shift: Double = 0) -> CGPoint {
            let r = phi * .pi / 180
            return K.add(K.add(skeleton.headCenter, up, K.headRy * k * cos(r) + shift), fwd, K.headRx * k * sin(r))
        }
        var path = Path()
        path.move(to: onHead(-125, 1.04))
        for phi in stride(from: -115.0, through: 45, by: 10) { path.addLine(to: onHead(phi, 1.04)) }
        for phi in stride(from: 45.0, through: -125, by: -10) { path.addLine(to: onHead(phi, 0.78, 1.6)) }
        path.closeSubpath()
        return path
    }

    private func drawLeg(_ l: K.Limb, near: Bool, fill: (Path, Color) -> Void, glowFill: (RigMuscleRegion, Path) -> Void) {
        let skin = near ? palette.skinNear : palette.skinFar
        let thigh = Self.capsule(skeleton.pelvis, l.knee, 8.2, 5.4)
        fill(thigh, skin)
        let shinPath = Self.capsule(l.knee, l.ankle, 5.2, 3.2)
        fill(shinPath, skin)
        let calfCenter = K.add(K.add(l.knee, l.shinDir, K.shin * 0.33), K.rotate(l.shinDir, -90), -2.2)
        let calf = Self.ellipse(center: calfCenter, rx: 4.8, ry: 8.5, along: l.shinDir)
        fill(calf, skin)

        glowFill(.thigh, thigh)
        glowFill(.thighFront, Self.halfCapsule(skeleton.pelvis, l.knee, 8.2, 5.4, front: true, axis: l.thighDir))
        glowFill(.thighBack, Self.halfCapsule(skeleton.pelvis, l.knee, 8.2, 5.4, front: false, axis: l.thighDir))
        glowFill(.shinFront, Self.halfCapsule(l.knee, l.ankle, 5.2, 3.2, front: true, axis: l.shinDir))
        glowFill(.shinBack, calf)

        let shortsEnd = K.add(skeleton.pelvis, l.thighDir, K.thigh * 0.58)
        fill(Self.capsule(skeleton.pelvis, shortsEnd, 9.2, 6.9), near ? palette.shortsNear : palette.shortsFar)

        var shoe = Path()
        let down = K.rotate(l.footDir, 90), upSide = K.rotate(l.footDir, -90)
        shoe.move(to: K.add(l.heel, down, 0.5))
        shoe.addLine(to: K.add(l.toe, down, 0.5))
        shoe.addQuadCurve(to: K.add(l.toe, upSide, 1.8), control: K.add(l.toe, l.footDir, 1.5))
        shoe.addLine(to: K.add(l.ankle, upSide, 4.6))
        shoe.addLine(to: K.add(l.heel, upSide, 4.2))
        shoe.closeSubpath()
        fill(shoe, palette.shoe)
        glowFill(.foot, shoe)
    }

    private func drawArm(_ l: K.Limb, near: Bool, fill: (Path, Color) -> Void, glowFill: (RigMuscleRegion, Path) -> Void) {
        let skin = near ? palette.skinNear : palette.skinFar
        let upper = Self.capsule(skeleton.shoulder, l.elbow, 5, 3.9)
        fill(upper, skin)
        let fore = Self.capsule(l.elbow, l.wrist, 3.8, 2.7)
        fill(fore, skin)
        let hand = Self.ellipse(center: K.add(l.wrist, l.handDir, K.hand * 0.5), rx: 2.8, ry: 4.6, along: l.handDir)
        fill(hand, skin)
        glowFill(.upperArmFront, Self.halfCapsule(skeleton.shoulder, l.elbow, 5, 3.9, front: true, axis: l.armDir))
        glowFill(.upperArmBack, Self.halfCapsule(skeleton.shoulder, l.elbow, 5, 3.9, front: false, axis: l.armDir))
        glowFill(.forearm, fore)
        let sleeveEnd = K.add(skeleton.shoulder, l.armDir, K.upperArm * 0.42)
        let sleeve = Self.capsule(skeleton.shoulder, sleeveEnd, 5.6, 4.7)
        fill(sleeve, near ? palette.shirtNear : palette.shirtFar)
        glowFill(.shoulderCap, Path(ellipseIn: CGRect(x: skeleton.shoulder.x - 5.6, y: skeleton.shoulder.y - 5.6, width: 11.2, height: 11.2)))
    }
}

/// §9: "a small named shape positioned relative to a joint" — balls, bars,
/// sticks, nets, hurdles, blocks.
private func propShape(for prop: PropInfo, at point: CGPoint) -> Path {
    var path = Path()
    switch prop.id {
    case "ball-round", "ball-oval", "puck":
        let r: Double = prop.id == "puck" ? 2.6 : 4.2
        path.addEllipse(in: CGRect(x: point.x - r, y: point.y - r * (prop.id == "ball-oval" ? 0.7 : 1), width: r * 2, height: r * 2 * (prop.id == "ball-oval" ? 0.7 : 1)))
    case "bar-barbell":
        path.move(to: CGPoint(x: point.x - 26, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 26, y: point.y))
    case "net-goal", "net-court":
        path.addRect(CGRect(x: point.x - 14, y: point.y - 16, width: 28, height: 22))
    case "hurdle":
        path.move(to: CGPoint(x: point.x - 9, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 9, y: point.y))
        path.move(to: CGPoint(x: point.x - 9, y: point.y))
        path.addLine(to: CGPoint(x: point.x - 9, y: point.y + 12))
        path.move(to: CGPoint(x: point.x + 9, y: point.y))
        path.addLine(to: CGPoint(x: point.x + 9, y: point.y + 12))
    case "blocks":
        path.addRect(CGRect(x: point.x - 7, y: point.y - 3, width: 14, height: 6))
    default: // stick, bat, racket, throwing implement
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x + 5, y: point.y - 22))
    }
    return path
}

/// The animated athlete.
public struct RigPoseView: View {
    private let start: [Joint: Double]
    private let end: [Joint: Double]
    private let mirrored: Bool
    private let prop: PropInfo?
    private let muscles: [String: Double]
    private let animated: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One-rep moves: the whole take, start hold → move → end hold → cut.
    static let repPeriod: Double = 2.4
    /// Continuous rhythms: one there-and-back stride.
    static let loopPeriod: Double = 1.1

    private let loops: Bool

    public init(
        start: [Joint: Double], end: [Joint: Double], loops: Bool = false, mirrored: Bool = false, prop: PropInfo? = nil,
        muscles: [String: Double] = [:], animated: Bool = true
    ) {
        self.start = start
        self.end = end
        self.loops = loops
        self.mirrored = mirrored
        self.prop = prop
        self.muscles = muscles
        self.animated = animated
    }

    /// A one-rep move plays start → end once, holds the finish so it reads,
    /// then cuts straight back to the start (no reverse morph). A rhythm
    /// (running, hopping) swings back and forth seamlessly instead.
    static func phase(at time: TimeInterval, loops: Bool) -> Double {
        if loops {
            let cycle = time.truncatingRemainder(dividingBy: loopPeriod) / loopPeriod
            return 0.5 - 0.5 * cos(cycle * 2 * .pi)
        }
        let cycle = time.truncatingRemainder(dividingBy: repPeriod) / repPeriod
        let moving = min(max((cycle - 0.14) / 0.56, 0), 1)
        return moving * moving * (3 - 2 * moving)
    }

    private var glow: [RigMuscleRegion: Double] {
        var out: [RigMuscleRegion: Double] = [:]
        for (slug, weight) in muscles {
            guard let info = musclesBySlug[slug] else { continue }
            let region = RigMuscleRegion.region(for: info.region, slug: slug)
            out[region] = max(out[region] ?? 0, MuscleRole(weight: weight).opacity)
        }
        return out
    }

    /// One fixed frame for the whole cycle, so the camera never jitters.
    private func cycleBounds() -> CGRect {
        var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
        for t in stride(from: 0.0, through: 1.0, by: 0.25) {
            let s = RigKinematics.skeleton(for: RigKinematics.interpolate(start, end, t), mirrored: mirrored)
            for p in s.points {
                minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }
        let pad: Double = 12
        return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: max(maxY, 2) - minY + pad + 4)
    }

    public var body: some View {
        let palette = RigRenderer.Palette.forScheme(colorScheme)
        let glow = glow
        let bounds = cycleBounds()
        let hangsFromBar = (start[.lift] ?? 0) > 0 && (start[.shoulderL] ?? 0) > 150
        let barY = hangsFromBar ? RigKinematics.skeleton(for: start, mirrored: mirrored).near.wrist.y : nil
        TimelineView(.animation(paused: !animated || reduceMotion)) { timeline in
            let t = (animated && !reduceMotion) ? Self.phase(at: timeline.date.timeIntervalSinceReferenceDate, loops: loops) : 0.65
            Canvas { context, size in
                let scale = min(size.width / bounds.width, size.height / bounds.height)
                let offsetX = (size.width - bounds.width * scale) / 2 - bounds.minX * scale
                let offsetY = (size.height - bounds.height * scale) / 2 - bounds.minY * scale
                let transform = CGAffineTransform(translationX: offsetX, y: offsetY).scaledBy(x: scale, y: scale)

                var ground = Path()
                ground.move(to: CGPoint(x: bounds.minX, y: 0))
                ground.addLine(to: CGPoint(x: bounds.maxX, y: 0))
                context.stroke(ground.applying(transform), with: .color(palette.ground), lineWidth: 1.2)

                if let barY {
                    var bar = Path()
                    bar.move(to: CGPoint(x: bounds.minX + 6, y: barY))
                    bar.addLine(to: CGPoint(x: bounds.maxX - 6, y: barY))
                    context.stroke(bar.applying(transform), with: .color(palette.shoe.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                let skeleton = RigKinematics.skeleton(for: RigKinematics.interpolate(start, end, t), mirrored: mirrored)
                RigRenderer(skeleton: skeleton, palette: palette, glow: glow, prop: prop)
                    .draw(in: &context, transform: transform)
            }
        }
        .accessibilityHidden(true) // decorative alongside the item's own text cues
    }
}

/// A still frame for list thumbnails — the most telling moment of the move.
struct RigStillView: View {
    let start: [Joint: Double]
    let end: [Joint: Double]
    let prop: PropInfo?

    var body: some View {
        RigPoseView(start: start, end: end, prop: prop, animated: false)
    }
}

/// Convenience initializer from a content-pack pose pattern's plain
/// `[String: Double]` dictionaries (as decoded from JSON), dropping anything
/// unrecognised rather than crashing on a pack authored for a newer model.
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
    return RigPoseView(start: pattern.start, end: pattern.end, muscles: ["rectus-femoris": 1, "gluteus-maximus": 1])
        .frame(height: 260)
        .padding()
}

#Preview("Instep strike with ball") {
    let pattern = posePatternsBySlug["instep-strike"]!
    return RigPoseView(start: pattern.start, end: pattern.end, prop: propsBySlug["ball-round"])
        .frame(height: 260)
        .padding()
}
