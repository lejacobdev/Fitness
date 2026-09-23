import Foundation
import simd

/// §9 job 2 — the exercise rig's maths: a 3D skeleton driven by joint
/// angles, played through a pattern's keyframes with planted feet, hands and
/// seats staying put. A line-for-line port of content/src/rig3d.js; the unit
/// test `RigEngineTests` checks it against `rigGoldenSamples`, which that
/// file generates, so the app and the previews can never drift apart.
typealias V3 = SIMD3<Double>

/// A rotation as three column vectors (local x, y, z in world space).
struct M3 {
    var c0: V3, c1: V3, c2: V3

    static let identity = M3(c0: V3(1, 0, 0), c1: V3(0, 1, 0), c2: V3(0, 0, 1))

    func apply(_ v: V3) -> V3 { c0 * v.x + c1 * v.y + c2 * v.z }
    static func * (a: M3, b: M3) -> M3 { M3(c0: a.apply(b.c0), c1: a.apply(b.c1), c2: a.apply(b.c2)) }

    /// + turns "down" toward "forward".
    static func rotZ(_ deg: Double) -> M3 {
        let c = cos(deg * .pi / 180), s = sin(deg * .pi / 180)
        return M3(c0: V3(c, s, 0), c1: V3(-s, c, 0), c2: V3(0, 0, 1))
    }
    /// + turns "up" toward "left".
    static func rotX(_ deg: Double) -> M3 {
        let c = cos(deg * .pi / 180), s = sin(deg * .pi / 180)
        return M3(c0: V3(1, 0, 0), c1: V3(0, c, s), c2: V3(0, -s, c))
    }
    /// + turns "forward" toward "left".
    static func rotY(_ deg: Double) -> M3 {
        let c = cos(deg * .pi / 180), s = sin(deg * .pi / 180)
        return M3(c0: V3(c, 0, s), c1: V3(0, 1, 0), c2: V3(-s, 0, c))
    }
}

@inline(__always) func normed(_ v: V3) -> V3 {
    let l = simd_length(v)
    return l == 0 ? v : v / l
}

enum RigBones {
    static let torso = 42.0, neck = 7.0, headR = 9.0, upperArm = 27.0, forearm = 24.0, hand = 8.0
    static let thigh = 40.0, shin = 39.0, foot = 15.0, heel = 3.5
    static let shoulderHalf = 15.0, hipHalf = 8.0, hipDrop = 2.0
}

enum RigViews {
    static func yaw(_ view: String) -> Double {
        switch view {
        case "front": 90
        case "three-quarter": 38
        case "back": -90
        case "rear-three-quarter": -142
        default: 0
        }
    }
    static let pitch = 8.0
}

/// Joint angles in `Joint.allCases` order, read by name.
struct RigAngles {
    var values: [Double]

    private static let index: [String: Int] = Dictionary(uniqueKeysWithValues: Joint.allCases.enumerated().map { ($1.rawValue, $0) })

    subscript(_ name: String) -> Double {
        get { Self.index[name].map { values[$0] } ?? 0 }
        set { if let i = Self.index[name] { values[i] = newValue } }
    }

    static func lerp(_ a: RigAngles, _ b: RigAngles, _ t: Double) -> RigAngles {
        RigAngles(values: zip(a.values, b.values).map { $0 + ($1 - $0) * t })
    }
}

struct RigLimb {
    var shoulder: V3, arm: M3, elbow: V3, fore: M3, wrist: V3, hand: M3, handTip: V3
    var hip: V3, thigh: M3, knee: V3, shin: M3, ankle: V3, foot: M3
    var footDir: V3, toe: V3, heel: V3

    func point(_ name: String) -> V3 {
        switch name {
        case "ankle": ankle
        case "toe": toe
        case "heel": heel
        case "wrist": wrist
        case "knee": knee
        default: ankle
        }
    }
}

struct RigSkeleton {
    var root: M3, trunk: M3, chest: M3, headFrame: M3
    var pelvis: V3, neckBase: V3, neckTop: V3, head: V3
    var L: RigLimb, R: RigLimb
    var twist: Double

    func limb(_ side: String) -> RigLimb { side == "L" ? L : R }

    func translated(by v: V3) -> RigSkeleton {
        var s = self
        s.pelvis += v; s.neckBase += v; s.neckTop += v; s.head += v
        for side in ["L", "R"] {
            var l = side == "L" ? s.L : s.R
            l.shoulder += v; l.elbow += v; l.wrist += v; l.handTip += v
            l.hip += v; l.knee += v; l.ankle += v; l.toe += v; l.heel += v
            if side == "L" { s.L = l } else { s.R = l }
        }
        return s
    }
}

enum RigKinematics3D {
    /// Joint positions for one pose, pelvis at the origin.
    static func skeleton(_ a: RigAngles, view: Double) -> RigSkeleton {
        let root = M3.rotY(view + a["turn"])
        let trunk = root * M3.rotZ(-a["spine"]) * M3.rotX(a["bend"])
        let chest = trunk * M3.rotY(a["twist"])
        let pelvis = V3.zero
        let neckBase = trunk.apply(V3(0, RigBones.torso, 0))
        let headFrame = chest * M3.rotZ(-a["neck"]) * M3.rotY(a["neckTurn"])
        let neckTop = neckBase + headFrame.apply(V3(0, RigBones.neck, 0))
        let head = neckTop + headFrame.apply(V3(0.8, RigBones.headR * 0.85, 0))

        func side(_ s: String) -> RigLimb {
            let σ: Double = s == "L" ? 1 : -1
            let shoulder = neckBase + chest.apply(V3(0, -3, σ * RigBones.shoulderHalf))
            let arm = chest * M3.rotZ(a["shoulder\(s)"]) * M3.rotX(-σ * a["shoulderAbd\(s)"]) * M3.rotY(-σ * a["shoulderRot\(s)"])
            let elbow = shoulder + arm.apply(V3(0, -RigBones.upperArm, 0))
            let fore = arm * M3.rotZ(a["elbow\(s)"])
            let wrist = elbow + fore.apply(V3(0, -RigBones.forearm, 0))
            let hand = fore * M3.rotZ(a["wrist\(s)"])
            let handTip = wrist + hand.apply(V3(0, -RigBones.hand, 0))
            let hip = pelvis + trunk.apply(V3(0, -RigBones.hipDrop, σ * RigBones.hipHalf))
            let thigh = trunk * M3.rotZ(a["hip\(s)"]) * M3.rotX(-σ * a["hipAbd\(s)"]) * M3.rotY(-σ * a["hipRot\(s)"])
            let knee = hip + thigh.apply(V3(0, -RigBones.thigh, 0))
            let shin = thigh * M3.rotZ(-a["knee\(s)"])
            let ankle = knee + shin.apply(V3(0, -RigBones.shin, 0))
            let foot = shin * M3.rotZ(a["ankle\(s)"])
            let footDir = foot.apply(V3(1, 0, 0))
            return RigLimb(shoulder: shoulder, arm: arm, elbow: elbow, fore: fore, wrist: wrist, hand: hand, handTip: handTip,
                           hip: hip, thigh: thigh, knee: knee, shin: shin, ankle: ankle, foot: foot, footDir: footDir,
                           toe: ankle + footDir * RigBones.foot, heel: ankle - footDir * RigBones.heel)
        }
        return RigSkeleton(root: root, trunk: trunk, chest: chest, headFrame: headFrame, pelvis: pelvis, neckBase: neckBase,
                           neckTop: neckTop, head: head, L: side("L"), R: side("R"), twist: a["twist"])
    }

    /// Floor-touching points with the body's thickness there.
    static func contactPoints(_ s: RigSkeleton) -> [(V3, Double)] {
        let fwd = s.trunk.apply(V3(1, 0, 0)), up = s.trunk.apply(V3(0, 1, 0)), lat = s.trunk.apply(V3(0, 0, 1))
        let chest = s.pelvis + up * (RigBones.torso * 0.75)
        var pts: [(V3, Double)] = [
            (s.pelvis + fwd * 8, 0), (s.pelvis - fwd * 9.5, 0), (s.pelvis + lat * 13, 0), (s.pelvis - lat * 13, 0),
            (chest + fwd * 10, 0), (chest - fwd * 9.2, 0), (chest + lat * 15, 0), (chest - lat * 15, 0),
            (s.head, RigBones.headR), (s.neckTop, 4),
        ]
        for l in [s.L, s.R] {
            pts += [(l.shoulder, 5), (l.elbow, 3.8), (l.wrist, 2.7), (l.handTip, 1.5), (l.knee, 5.2), (l.ankle, 0), (l.toe, 0), (l.heel, 0)]
        }
        return pts
    }

    static func lowestY(_ s: RigSkeleton) -> Double {
        contactPoints(s).map { $0.0.y - $0.1 }.min() ?? 0
    }

    static func flattenFoot(_ l: RigLimb, _ w: Double) -> RigLimb {
        guard w > 0 else { return l }
        let heading = l.shin.apply(V3(1, 0, 0))
        let flat = normed(V3(heading.x, 0, heading.z))
        let dir = normed(l.footDir * (1 - w) + flat * w)
        var out = l
        out.footDir = dir
        out.toe = l.ankle + dir * RigBones.foot
        out.heel = l.ankle - dir * RigBones.heel
        return out
    }
}

// MARK: - Contacts

/// A keyframe's contact string ('L+Rtoe', 'hands+knees', 'seat+feet'…) parsed once.
struct RigContact: Equatable {
    var tokens: Set<String>

    init(_ raw: String) {
        var t = Set(raw.split(separator: "+").map(String.init))
        if t.contains("feet") { t.insert("L"); t.insert("R") }
        if t.contains("hands") { t.insert("Lhand"); t.insert("Rhand") }
        if t.contains("knees") { t.insert("Lknee"); t.insert("Rknee") }
        tokens = t
    }

    func has(_ token: String) -> Bool { tokens.contains(token) }
    func flat(_ side: String) -> Bool { has(side) }
    func plant(_ side: String) -> String? {
        if has(side) { return "ankle" }
        if has("\(side)toe") { return "toe" }
        if has("\(side)heel") { return "heel" }
        return nil
    }
    var selfPinned: Bool { has("grip") || has("seat") || has("water") }
}

struct RigShared {
    var kind: String // "parts", "grip", "seat", "water"
    var parts: [(side: String, point: String)]
    var pinsHeight: Bool { kind == "grip" || kind == "seat" || kind == "water" }

    static func between(_ a: RigContact, _ b: RigContact) -> RigShared? {
        var parts: [(String, String)] = []
        for side in ["L", "R"] {
            if let pa = a.plant(side), let pb = b.plant(side) {
                let point = pa == pb ? pa : (pa == "ankle" ? pb : (pb == "ankle" ? pa : "ankle"))
                parts.append((side, point))
            }
        }
        for side in ["L", "R"] {
            if a.has("\(side)hand") && b.has("\(side)hand") { parts.append((side, "wrist")) }
            if a.has("\(side)knee") && b.has("\(side)knee") { parts.append((side, "knee")) }
        }
        for pin in ["grip", "seat", "water"] where a.has(pin) && b.has(pin) {
            return RigShared(kind: pin, parts: parts)
        }
        return parts.isEmpty ? nil : RigShared(kind: "parts", parts: parts)
    }

    func anchor(_ s: RigSkeleton) -> V3 {
        if !parts.isEmpty {
            let pts = parts.map { s.limb($0.side).point($0.point) }
            return pts.reduce(V3.zero, +) / Double(pts.count)
        }
        if kind == "grip" { return (s.L.wrist + s.R.wrist) / 2 }
        return s.pelvis
    }

    func heightPoint(_ s: RigSkeleton) -> V3 {
        kind == "grip" ? (s.L.wrist + s.R.wrist) / 2 : s.pelvis
    }

    /// The same parts as a contact, for height pinning.
    var asContact: RigContact {
        RigContact(parts.map { part -> String in
            switch part.point {
            case "ankle": part.side
            case "toe": "\(part.side)toe"
            case "heel": "\(part.side)heel"
            case "wrist": "\(part.side)hand"
            default: "\(part.side)knee"
            }
        }.joined(separator: "+"))
    }
}

// MARK: - Playback

/// One pattern, parsed and placed once, ready to produce any frame.
final class RigPlayback {
    let info: PosePatternInfo
    let view: Double
    let angles: [RigAngles]
    let contacts: [RigContact]
    let raw: [RigSkeleton]
    private(set) var offsets: [V3] = []
    let cycleSeconds: Double

    init(_ info: PosePatternInfo) {
        self.info = info
        view = RigViews.yaw(info.view)
        angles = info.keyframes.map { RigAngles(values: $0.angles) }
        contacts = info.keyframes.map { RigContact($0.contact) }
        raw = angles.map { RigKinematics3D.skeleton($0, view: RigViews.yaw(info.view)) }
        let moves = info.loops ? info.keyframes.count : info.keyframes.count - 1
        var total = 0.0
        for (i, k) in info.keyframes.enumerated() {
            total += k.hold
            if i < moves { total += k.move }
        }
        cycleSeconds = max(total, 0.1)
        place()
    }

    private func flattenBoth(_ s: RigSkeleton, _ c0: RigContact, _ c1: RigContact, _ u: Double = 0) -> RigSkeleton {
        var out = s
        func w(_ side: String) -> Double { (c0.flat(side) ? 1 : 0) + ((c1.flat(side) ? 1 : 0) - (c0.flat(side) ? 1 : 0)) * u }
        out.L = RigKinematics3D.flattenFoot(s.L, w("L"))
        out.R = RigKinematics3D.flattenFoot(s.R, w("R"))
        return out
    }

    private func groundY(_ s: RigSkeleton, _ surface: Double, _ lift: Double) -> Double {
        surface - RigKinematics3D.lowestY(s) + lift
    }

    private func contactY(_ s: RigSkeleton, _ c: RigContact, _ surface: Double, _ lift: Double) -> Double {
        var heights: [Double] = []
        for side in ["L", "R"] {
            let l = s.limb(side)
            if c.has(side) { heights.append(l.ankle.y) }
            else if c.has("\(side)toe") { heights.append(l.toe.y) }
            else if c.has("\(side)heel") { heights.append(l.heel.y) }
            if c.has("\(side)hand") { heights.append(min(l.wrist.y - 2.7, l.handTip.y - 1.5)) }
            if c.has("\(side)knee") { heights.append(l.knee.y - 5.2) }
        }
        return heights.isEmpty ? groundY(s, surface, lift) : surface - (heights.min() ?? 0)
    }

    private func place() {
        let frames = info.keyframes
        var result: [V3] = []
        for i in frames.indices {
            let s = flattenBoth(raw[i], contacts[i], contacts[i])
            let surface = frames[i].surface
            let lift = angles[i]["lift"]
            if i == 0 {
                result.append(V3(0, contactY(s, contacts[i], surface, lift), 0))
                continue
            }
            let shared = RigShared.between(contacts[i - 1], contacts[i])
            var x: Double, z: Double
            if let shared {
                let prevS = flattenBoth(raw[i - 1], contacts[i - 1], contacts[i - 1])
                let pinned = shared.anchor(prevS) + result[i - 1]
                let here = shared.anchor(s)
                x = pinned.x - here.x
                z = pinned.z - here.z
            } else {
                let t = frames[i].travel
                let w = M3.rotY(view).apply(V3(t.first ?? 0, 0, t.count > 1 ? t[1] : 0))
                x = result[i - 1].x + w.x
                z = result[i - 1].z + w.z
            }
            var y: Double
            if let shared, shared.pinsHeight {
                let a = shared.heightPoint(flattenBoth(raw[i - 1], contacts[i - 1], contacts[i - 1]))
                let b = shared.heightPoint(s)
                y = a.y + result[i - 1].y - b.y
            } else {
                y = contactY(s, contacts[i], surface, lift)
            }
            result.append(V3(x, y, z))
        }
        offsets = result
    }

    static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    private func ease(_ k: Int, _ u: Double) -> Double {
        let chain = info.keyframes[k].chain
        let index = Double(chain.first ?? 0), count = Double(chain.count > 1 ? chain[1] : 1)
        return Self.smooth((index + u) / count) * count - index
    }

    /// Segment and progress along it for a cycle position in [0, 1).
    func timing(_ t: Double) -> (segment: Int, u: Double) {
        let frames = info.keyframes
        let n = frames.count
        let moves = info.loops ? n : n - 1
        var spans: [(hold: Bool, i: Int, d: Double)] = []
        for i in 0..<n {
            spans.append((true, i, frames[i].hold))
            if i < moves { spans.append((false, i, frames[i].move)) }
        }
        let total = spans.reduce(0) { $0 + $1.d }
        var at = (t.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * total
        for (index, span) in spans.enumerated() {
            if at <= span.d || index == spans.count - 1 {
                if span.hold {
                    if span.i == n - 1 && !info.loops { return (max(0, n - 2), 1) }
                    return (span.i, 0)
                }
                return (span.i, span.d > 0 ? min(1, at / span.d) : 1)
            }
            at -= span.d
        }
        return (0, 0)
    }

    /// The placed skeleton at cycle position `t` in [0, 1).
    func frame(at t: Double) -> RigSkeleton {
        let (segment, u) = timing(t)
        let n = info.keyframes.count
        let j = (segment + 1) % n
        var pose = RigAngles.lerp(angles[segment], angles[j], ease(segment, u))
        var s = frameFor(segment, u, pose)
        guard let shared = RigShared.between(contacts[segment], contacts[j]), shared.kind == "parts" else { return s }
        let planted = Set(shared.parts.filter { ["ankle", "toe", "heel"].contains($0.point) }.map(\.side))
        let surface = min(info.keyframes[segment].surface, info.keyframes[j].surface)
        for side in ["L", "R"] where !planted.contains(side) {
            func low(_ sk: RigSkeleton) -> Double {
                let l = sk.limb(side)
                return min(l.ankle.y, l.toe.y, l.heel.y) - surface
            }
            var n2 = 0
            while n2 < 40 && low(s) < -0.5 && pose["knee\(side)"] < 150 {
                pose["knee\(side)"] += 3
                s = frameFor(segment, u, pose)
                n2 += 1
            }
        }
        return s
    }

    private func frameFor(_ i: Int, _ u: Double, _ pose: RigAngles) -> RigSkeleton {
        let n = info.keyframes.count
        let j = (i + 1) % n
        let k0 = info.keyframes[i], k1 = info.keyframes[j]
        let c0 = contacts[i], c1 = contacts[j]
        let e = ease(i, u)
        var s = RigKinematics3D.skeleton(pose, view: view)
        s = flattenBoth(s, c0, c1, e)
        let shared = RigShared.between(c0, c1)
        let o0 = offsets[i]
        let o1 = j == 0 ? offsets[0] : offsets[j]
        var x = o0.x + (o1.x - o0.x) * e, z = o0.z + (o1.z - o0.z) * e
        if let shared {
            let s0 = flattenBoth(raw[i], c0, c0)
            let pinned = shared.anchor(s0) + o0
            let here = shared.anchor(s)
            x = pinned.x - here.x
            z = pinned.z - here.z
        }
        let surface = k0.surface + (k1.surface - k0.surface) * e
        let lift = pose["lift"]
        var y: Double
        if let shared, shared.pinsHeight {
            let s0 = flattenBoth(raw[i], c0, c0)
            y = shared.heightPoint(s0).y + o0.y - shared.heightPoint(s).y
        } else if c0.selfPinned || c1.selfPinned {
            y = o0.y + (o1.y - o0.y) * e
        } else if let shared {
            y = contactY(s, shared.asContact, surface, lift)
        } else {
            let a = contactY(s, c0, k0.surface, lift), b = contactY(s, c1, k1.surface, lift)
            y = a + (b - a) * e
            y = max(y, groundY(s, min(k0.surface, k1.surface), 0))
        }
        return s.translated(by: V3(x, y, z))
    }

    /// Keyframe `i` exactly as placed.
    func keyframe(_ i: Int) -> RigSkeleton {
        flattenBoth(raw[i], contacts[i], contacts[i]).translated(by: offsets[i])
    }

    // MARK: Fixture placement (body axes around keyframe 0's pelvis)

    struct Fixture {
        var kind: String
        var origin: V3
        var view: Double
        var numbers: [String: Double] = [:]
        var points: [String: V3] = [:]
    }

    lazy var fixture: Fixture? = placeFixture()

    private func placeFixture() -> Fixture? {
        guard let fx = info.fixture else { return nil }
        let k0 = keyframe(0)
        let pel = k0.pelvis
        let back = M3.rotY(-view)
        func toBody(_ p: V3) -> V3 { pel + back.apply(p - pel) }
        func bodySkel(_ sk: RigSkeleton) -> RigSkeleton {
            var b = sk
            b.trunk = back * sk.trunk
            b.pelvis = toBody(sk.pelvis); b.neckBase = toBody(sk.neckBase)
            for side in ["L", "R"] {
                var l = sk.limb(side)
                l.shoulder = toBody(l.shoulder); l.elbow = toBody(l.elbow); l.wrist = toBody(l.wrist); l.handTip = toBody(l.handTip)
                l.hip = toBody(l.hip); l.knee = toBody(l.knee); l.ankle = toBody(l.ankle); l.toe = toBody(l.toe); l.heel = toBody(l.heel)
                if side == "L" { b.L = l } else { b.R = l }
            }
            return b
        }
        let b0 = bodySkel(k0)
        let all = info.keyframes.indices.map { bodySkel(keyframe($0)) }
        var out = Fixture(kind: fx.kind, origin: pel, view: view)
        let p = fx.params
        switch fx.kind {
        case "kickball":
            let k = bodySkel(keyframe(Int(p["frame"] ?? 1)))
            let toe = k.limb(fx.under == "R" ? "R" : "L").toe
            out.points["ball"] = V3(toe.x + 5, 5.8, toe.z)
        case "bench", "box":
            if fx.under == "Lfoot" || fx.under == "Rfoot" {
                let a = b0.limb(fx.under == "Lfoot" ? "L" : "R").ankle
                let w = (p["width"] ?? 30) / 2
                out.numbers = ["x0": a.x - w, "x1": a.x + w, "top": p["top"] ?? a.y - 3, "z": a.z]
            } else if fx.under == "hands" || fx.under == "feet" {
                let c = fx.under == "hands" ? (b0.L.wrist + b0.R.wrist) / 2 : (b0.L.ankle + b0.R.ankle) / 2
                let w = (p["width"] ?? 36) / 2, shift = p["shift"] ?? 0
                out.numbers = ["x0": c.x - w + shift, "x1": c.x + w + shift, "top": p["top"] ?? 34, "z": pel.z]
            } else {
                out.numbers = ["x0": pel.x + (p["from"] ?? -20), "x1": pel.x + (p["to"] ?? 20),
                               "top": p["top"] ?? pel.y + (p["below"] ?? -10), "z": pel.z]
            }
        case "wall":
            out.numbers = ["x": pel.x + (p["at"] ?? -12)]
        case "incline":
            let upv = b0.trunk.apply(V3(0, 1, 0)), fw = b0.trunk.apply(V3(1, 0, 0))
            let from = pel - fw * 13 + upv * 4, to = pel - fw * 13 + upv * 44
            out.numbers = ["seatX": pel.x, "seatTop": pel.y - 10]
            out.points = ["padFrom": from, "padTo": to]
        case "bar":
            out.points["at"] = (b0.L.wrist + b0.R.wrist) / 2 + V3(0, 3, 0)
        case "water":
            out.numbers = ["level": pel.y + (p["level"] ?? 6), "x0": pel.x - 120, "x1": pel.x + 120]
        case "mat":
            let xs = all.flatMap { sk in RigKinematics3D.contactPoints(sk).map(\.0.x) }
            out.numbers = ["x0": (xs.min() ?? 0) - 8, "x1": (xs.max() ?? 0) + 8]
        case "bike":
            let ankles = all.flatMap { [$0.L.ankle, $0.R.ankle] }
            let crank = ankles.reduce(V3.zero, +) / Double(max(ankles.count, 1))
            let r = ankles.map { hypot($0.x - crank.x, $0.y - crank.y) }.max() ?? 17
            out.numbers = ["r": r]
            out.points = ["crank": V3(crank.x, crank.y, pel.z), "seat": V3(pel.x - 2 - (p["seatBack"] ?? 0), pel.y - 6 - (p["seatDrop"] ?? 0), pel.z),
                          "bars": V3(((b0.L.wrist + b0.R.wrist) / 2).x, ((b0.L.wrist + b0.R.wrist) / 2).y, pel.z)]
        case "rower":
            let foot = (b0.L.ankle + b0.R.ankle) / 2
            let xs = all.map(\.pelvis.x)
            out.numbers = ["seatTop": pel.y - 10, "rail0": (xs.min() ?? 0) - 20, "rail1": foot.x + 8]
            out.points = ["foot": foot, "fly": V3(foot.x + 20, foot.y + 2, pel.z)]
        case "hurdle", "cone", "ladder", "sled":
            out.numbers = ["x": pel.x + (p["at"] ?? 30)]
        case "net":
            out.numbers = ["x": pel.x + (p["at"] ?? 30), "top": p["top"] ?? 150]
        case "wheelchair":
            out.points["seat"] = V3(pel.x, pel.y - 9, pel.z)
        case "roller":
            let target: V3
            if fx.under == "back" { target = pel + b0.trunk.apply(V3(0, 1, 0)) * 25 }
            else if fx.under == "calves" { target = (b0.L.knee + b0.L.ankle) / 2 }
            else { target = (b0.L.hip + b0.L.knee) / 2 }
            out.points["at"] = V3(target.x, 7, pel.z)
        case "ball":
            out.points["at"] = V3(pel.x + (p["dx"] ?? 0), p["r"] ?? 30, pel.z)
            out.numbers["r"] = p["r"] ?? 30
        default:
            return nil
        }
        return out
    }
}

/// Projection: world → screen (x right, y down) and depth (bigger = nearer).
enum RigProjection {
    static let c = cos(RigViews.pitch * .pi / 180), s = sin(RigViews.pitch * .pi / 180)
    static func point(_ p: V3) -> CGPoint { CGPoint(x: p.x, y: -(p.y * c - p.z * s)) }
    static func depth(_ p: V3) -> Double { p.z * c + p.y * s }
}

/// Parsed playbacks, built once per pattern.
@MainActor
enum RigPlaybackCache {
    private static var cache: [String: RigPlayback] = [:]

    static func playback(for pattern: PosePatternInfo) -> RigPlayback {
        if let hit = cache[pattern.id] { return hit }
        let made = RigPlayback(pattern)
        cache[pattern.id] = made
        return made
    }
}
