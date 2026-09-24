import Foundation

/// §9 job 2 — the exercise rig's maths: a 3D skeleton driven by joint
/// angles, played through a pattern's keyframes with planted feet, hands and
/// seats staying put. A line-for-line port of content/src/rig3d.js; the unit
/// test `RigEngineTests` checks it against `rigGoldenSamples`, which that
/// file generates, so the app and the previews can never drift apart.
/// A plain 3D vector. (Deliberately not SIMD3: its many operator overloads
/// make long vector expressions extremely slow for the Swift type checker.)
struct V3: Equatable {
    var x: Double, y: Double, z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    static let zero = V3(0, 0, 0)

    static func + (a: V3, b: V3) -> V3 { V3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: V3, b: V3) -> V3 { V3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (a: V3, k: Double) -> V3 { V3(a.x * k, a.y * k, a.z * k) }
    static func / (a: V3, k: Double) -> V3 { V3(a.x / k, a.y / k, a.z / k) }
    static prefix func - (a: V3) -> V3 { V3(-a.x, -a.y, -a.z) }
    static func += (a: inout V3, b: V3) { a = a + b }

    func dot(_ b: V3) -> Double { x * b.x + y * b.y + z * b.z }
    func cross(_ b: V3) -> V3 { V3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    var length: Double { (x * x + y * y + z * z).squareRoot() }
}

/// A rotation as three column vectors (local x, y, z in world space).
struct M3 {
    var c0: V3, c1: V3, c2: V3

    static let identity = M3(c0: V3(1, 0, 0), c1: V3(0, 1, 0), c2: V3(0, 0, 1))

    func apply(_ v: V3) -> V3 {
        V3(c0.x * v.x + c1.x * v.y + c2.x * v.z, c0.y * v.x + c1.y * v.y + c2.y * v.z, c0.z * v.x + c1.z * v.y + c2.z * v.z)
    }
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
    let l = v.length
    return l == 0 ? v : v / l
}

enum RigBones {
    /// Bottom hand to the centre of a lacrosse head (rig3d.js LACROSSE_HEAD).
    static let lacrosseHead = 96.0
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
    /// The ball's centre, for patterns with a ball (nil when out of play).
    var ball: V3? = nil
    /// The other people in the drill, placed in the same world.
    var cast: [RigCastMember] = []
    /// Ground height under the athlete (non-zero on a hill path).
    var floor: Double = 0
    /// The fixture's own motion: a bike's pitch (degrees, nose up) and lift.
    var fxPitch: Double = 0, fxLift: Double = 0, fxShift: Double = 0
    /// On a path, the fixture travels with the athlete: turned, then moved.
    var fxMove: (heading: Double, offset: V3)? = nil

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
            // The sit bones, so a body sitting on the floor rests on them.
            (s.pelvis - up * 9, 0),
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
/// One other person in a drill, as placed at a moment.
struct RigCastMember {
    var s: RigSkeleton
    let playback: RigPlayback
    let follow: Bool
    let tether: Bool
}

final class RigPlayback {
    let info: PosePatternInfo
    let view: Double
    let angles: [RigAngles]
    let contacts: [RigContact]
    let raw: [RigSkeleton]
    private(set) var offsets: [V3] = []
    let cycleSeconds: Double

    init(_ info: PosePatternInfo, view viewOverride: Double? = nil) {
        self.info = info
        let yaw = viewOverride ?? RigViews.yaw(info.view)
        view = yaw
        angles = info.keyframes.map { RigAngles(values: $0.angles) }
        contacts = info.keyframes.map { RigContact($0.contact) }
        raw = angles.map { RigKinematics3D.skeleton($0, view: yaw) }
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
                // In water, `surface` sets how much deeper the body goes (a flip turn).
                if shared.kind == "water" { y += info.keyframes[i].surface - info.keyframes[i - 1].surface }
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

    /// The placed skeleton at cycle position `t` in [0, 1), with the ball.
    func frame(at t: Double) -> RigSkeleton {
        frame(at: t, cast: info.cast == nil ? [] : castAt(t))
    }

    func frame(at t: Double, cast: [RigCastMember]) -> RigSkeleton {
        let (segment, u) = timing(t)
        var s = body(segment, u)
        if info.fixture != nil {
            let k0 = info.keyframes[segment], k1 = info.keyframes[(segment + 1) % info.keyframes.count]
            let e = ease(segment, u)
            s.fxPitch = k0.fxPitch + (k1.fxPitch - k0.fxPitch) * e
            s.fxLift = k0.fxLift + (k1.fxLift - k0.fxLift) * e
            s.fxShift = k0.fxShift + (k1.fxShift - k0.fxShift) * e
            // The rider goes where the bike goes.
            if s.fxShift != 0 || s.fxLift != 0 {
                s = s.translated(by: M3.rotY(view).apply(V3(s.fxShift, 0, 0)) + V3(0, s.fxLift, 0))
            }
        }
        if info.ball != nil { s.ball = ballAt(segment, u, s, cast) }
        return s
    }

    // MARK: Cast (port of rig3d.js castAt)

    /// Each member's playback, placed in this pattern's camera view.
    lazy var castPlaybacks: [(spec: RigCastSpec, playback: RigPlayback)] = (info.cast ?? []).compactMap { spec in
        guard let pattern = posePatternsBySlug[spec.pattern] else { return nil }
        return (spec, RigPlayback(pattern, view: view))
    }

    func castAt(_ t: Double) -> [RigCastMember] {
        castPlaybacks.map { spec, playback in
            let u = ((t + spec.phase).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
            var s = playback.frame(at: u, cast: [])
            s.ball = nil
            let at = M3.rotY(view).apply(V3(spec.at.first ?? 0, spec.at.count > 2 ? spec.at[2] : 0, spec.at.count > 1 ? spec.at[1] : 0))
            return RigCastMember(s: s.moved(turning: spec.facing, by: at), playback: playback, follow: spec.follow, tether: spec.tether)
        }
    }

    // MARK: Ball (port of rig3d.js ballAt / ballPoint)

    private var keyframeCache: [Int: RigSkeleton] = [:]
    private func placedKeyframe(_ i: Int) -> RigSkeleton {
        if let hit = keyframeCache[i] { return hit }
        let k = keyframe(i)
        keyframeCache[i] = k
        return k
    }

    private func ballAt(_ segment: Int, _ u: Double, _ s: RigSkeleton, _ cast: [RigCastMember]) -> V3? {
        let n = info.keyframes.count
        let j = (segment + 1) % n
        let e = ease(segment, u)
        let b0 = ballPoint(segment, s, cast), b1 = ballPoint(j, s, cast)
        switch (b0, b1) {
        case (nil, nil): return nil
        case (nil, let b?): return e > 0.5 ? b : nil
        case (let a?, nil): return e < 0.5 ? a : nil
        case (let a?, let b?):
            let arc = info.keyframes[segment].ballArc
            return a * (1 - e) + b * e + V3(0, arc * 4 * e * (1 - e), 0)
        }
    }

    private func ballPoint(_ index: Int, _ skeleton: RigSkeleton, _ cast: [RigCastMember]) -> V3? {
        let spec = info.keyframes[index].ball ?? PoseBall(kind: "hands", side: nil, dx: nil, dl: nil, at: nil)
        let r = info.ball?.r ?? 6
        func grip(_ l: RigLimb) -> V3 { l.wrist + l.hand.apply(V3(0, -1, 0)) * 3.5 }
        // "c0:L" — with cast member 0 (their hand, foot, stick…).
        var kind = spec.kind
        var current = skeleton
        var implement = info.implement
        if kind.hasPrefix("c"), let colon = kind.firstIndex(of: ":"), let idx = Int(kind[kind.index(after: kind.startIndex)..<colon]) {
            guard idx < cast.count else { return nil }
            current = cast[idx].s
            implement = cast[idx].playback.info.implement
            kind = String(kind[kind.index(after: colon)...])
        }
        switch kind {
        case "none":
            return nil
        case "head":
            // Where the held implement meets the ball (as rig3d.js implementHead).
            let lengths: [String: Double] = ["bat": 48, "club": 58, "stick": 56, "racket": 30, "paddle": 20, "lacrosse": 50]
            let kind = implement?.kind ?? "racket"
            let fwFlat = normed(V3(current.root.apply(V3(1, 0, 0)).x, 0, current.root.apply(V3(1, 0, 0)).z))
            if kind == "hockeystick" {
                let leftTop = implement?.flags.contains("leftTop") == true
                let top = grip(leftTop ? current.L : current.R), dir = normed(grip(leftTop ? current.R : current.L) - top)
                let length = implement?.numbers["length"] ?? 128
                let toIce = dir.y < -0.15 ? (top.y - 1) / -dir.y : .infinity
                let heel = top + dir * min(length - 10, toIce)
                let blade = normed(fwFlat - dir * fwFlat.dot(dir))
                let p = heel + blade * 9 + fwFlat * 5
                return V3(p.x, max(r, heel.y), p.z)
            }
            if kind == "lacrosse2" {
                let lo = grip(current.L), dir = normed(grip(current.R) - lo)
                let face = normed(fwFlat - dir * fwFlat.dot(dir))
                return lo + dir * (implement?.numbers["head"] ?? RigBones.lacrosseHead) + face * max(0, r - 2)
            }
            if kind == "bat2" {
                let lo = grip(current.L), hi = grip(current.R)
                return lo + normed(hi - lo) * 48
            }
            let h = current.limb(implement?.at == "L" ? "L" : "R")
            let g = grip(h)
            let dir = normed(h.hand.apply(V3(0, -1, 0)) + h.fore.apply(V3(0, -1, 0)) * 0.6)
            let len = lengths[kind] ?? 30
            let along = kind == "racket" ? len + 9 : (kind == "paddle" ? len + 6 : (kind == "bat" ? len - 8 : len))
            return g + dir * along + h.hand.apply(V3(1, 0, 0)) * (r + 1)
        case "L", "R":
            let l = current.limb(kind)
            return grip(l) + l.hand.apply(V3(1, 0, 0)) * (r * 0.9)
        case "Ldown", "Rdown":
            return grip(current.limb(String(kind.prefix(1)))) + V3(0, -(r + 1.5), 0)
        case "footL", "footR":
            let l = current.limb(String(kind.suffix(1)))
            return l.toe + current.root.apply(V3(1, 0, 0)) * (r * 0.6) + V3(0, r, 0)
        case "floor", "at":
            let k = placedKeyframe(index)
            let fw = M3.rotY(view).apply(V3(1, 0, 0)), lt = M3.rotY(view).apply(V3(0, 0, 1))
            if kind == "floor" {
                let g = spec.side == "hands" ? (grip(k.L) + grip(k.R)) / 2 : grip(k.limb(spec.side ?? "R"))
                return V3(g.x, r + info.keyframes[index].surface, g.z) + fw * (spec.dx ?? 0) + lt * (spec.dl ?? 0)
            }
            let a = spec.at ?? [0, 0, 0]
            return k.pelvis + fw * a[0] + V3(0, a[1], 0) + lt * (a.count > 2 ? a[2] : 0)
        default:
            return (grip(current.L) + grip(current.R)) / 2 + current.chest.apply(V3(1, 0, 0)) * (r * 0.8)
        }
    }

    private func body(_ segment: Int, _ u: Double) -> RigSkeleton {
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
            if shared.kind == "water" { y += (k1.surface - k0.surface) * e }
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
        // placeFrom: lay the fixture out from that keyframe on (a bike you run up to).
        let from = min(Int(fx.params["placeFrom"] ?? 0), info.keyframes.count - 1)
        let k0 = keyframe(from)
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
        let to = fx.params["placeTo"].map { Int($0) } ?? info.keyframes.count
        let all = info.keyframes.indices.dropFirst(from).prefix(max(0, to - from)).map { bodySkel(keyframe($0)) }
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
            if let deck = p["deck"] { out.numbers["deckX"] = pel.x + deck; out.numbers["deckTop"] = p["deckTop"] ?? 30 }
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
        case "hurdle", "cone", "ladder", "sled", "control":
            out.numbers = ["x": pel.x + (p["at"] ?? 30)]
        case "net":
            out.numbers = ["x": pel.x + (p["at"] ?? 30), "top": p["top"] ?? 150]
        case "wheelchair", "racingchair":
            out.points["seat"] = V3(pel.x, pel.y - 9, pel.z)
        case "blocks":
            out.points["L"] = b0.L.toe
            out.points["R"] = b0.R.toe
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

// MARK: - Paths (port of rig3d.js strideSpeed / pathSeconds / pathAt / frameAtTime)

extension RigPlayback {
    private static let pathAxes: [String: V3] = ["forward": V3(1, 0, 0), "back": V3(-1, 0, 0), "left": V3(0, 0, 1), "right": V3(0, 0, -1)]

    /// How fast the planted foot slides back under the body (units/second).
    func strideSpeed(axis: V3) -> Double {
        let n = 48
        let dir = M3.rotY(view).apply(axis)
        var dist = 0.0, time = 0.0
        var prev: (foot: String, p: V3)?
        func low(_ l: RigLimb) -> V3 { [l.ankle, l.toe, l.heel].min { $0.y < $1.y } ?? l.ankle }
        for i in 0...n {
            let s = frame(at: Double(i) / Double(n))
            let pl = low(s.L), pr = low(s.R)
            let foot = pl.y <= pr.y ? "L" : "R"
            let p = foot == "L" ? pl : pr
            if let prev, prev.foot == foot, max(p.y, prev.p.y) < 3 {
                dist += -(p - prev.p).dot(dir)
                time += cycleSeconds / Double(n)
            }
            prev = (foot, p)
        }
        return time > 0 ? max(0, dist / time) : 0
    }

    /// Seconds for one full pass (the whole animation loop).
    var loopSeconds: Double {
        guard let path = info.path else { return cycleSeconds }
        let axis = Self.pathAxes[path.dir ?? "forward"] ?? V3(1, 0, 0)
        let speed = path.speed ?? max(strideSpeed(axis: axis), 20)
        let radius: Double = path.radius ?? 100
        let length: Double
        switch path.kind {
        case "arc": length = 2 * Double.pi * radius * (path.angle ?? 90) / 180
        case "circle": length = 2 * Double.pi * radius
        case "figure8": length = 4 * Double.pi * radius
        case "shuttle": length = (path.length ?? 200) * 2
        default: length = path.length ?? 200
        }
        return length / speed
    }

    /// Slope of a line path at `seconds` (hill grade plus rollers).
    func pathSlope(_ seconds: Double, total: Double) -> Double {
        guard let path = info.path, path.kind == "line" else { return 0 }
        let u = ((seconds / total).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let length = path.length ?? 200
        let along = -length / 2 + length * u
        var slope = path.grade ?? 0
        if let amp = path.waveAmp, let len = path.waveLength { slope += amp * 2 * .pi / len * cos(2 * .pi / len * along) }
        return slope
    }

    /// Position (body axes) and heading (degrees) along the path at `seconds`.
    func pathAt(_ seconds: Double, total: Double) -> (pos: V3, heading: Double) {
        guard let path = info.path else { return (.zero, 0) }
        let u = ((seconds / total).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        if path.kind == "circle" {
            let turn = path.turn ?? 1, r = path.radius ?? 100
            let theta = 2 * Double.pi * u
            return (V3(r * sin(theta), 0, turn * r * (1 - cos(theta))), turn * theta * 180 / .pi)
        }
        if path.kind == "arc" {
            // Sideways along an arc round a centre `radius` behind, facing out from it.
            let r = path.radius ?? 100
            let phi = (path.angle ?? 90) / 2 * sin(2 * .pi * u) * .pi / 180
            return (V3(r * cos(phi) - r, 0, r * sin(phi)), phi * 180 / .pi)
        }
        if path.kind == "figure8" {
            // One circle to the left, then one to the right, through the origin.
            let r = path.radius ?? 100
            let half: Double = u < 0.5 ? 1 : -1
            let theta = 4 * Double.pi * (u < 0.5 ? u : u - 0.5)
            return (V3(r * sin(theta), 0, half * r * (1 - cos(theta))), half * theta * 180 / .pi)
        }
        let axis = Self.pathAxes[path.dir ?? "forward"] ?? V3(1, 0, 0)
        let length = path.length ?? 200
        if path.kind == "shuttle" {
            let half = u < 0.5
            let along = half ? -length / 2 + length * (u * 2) : length / 2 - length * ((u - 0.5) * 2)
            return (axis * along, half ? 0 : 180)
        }
        let along = -length / 2 + length * u
        // grade: a hill; wave: rollers of height waveAmp every waveLength (a pump track).
        var y = along * (path.grade ?? 0)
        if let amp = path.waveAmp, let len = path.waveLength { y += amp * sin(2 * .pi / len * along) }
        return (axis * along + V3(0, y, 0), 0)
    }

    /// The skeleton at `seconds` of real time, carried along its path.
    func frame(atTime seconds: Double, loop: Double) -> RigSkeleton {
        let t = ((seconds / cycleSeconds).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        var cast = info.cast == nil ? [] : castAt(t)
        var s = frame(at: t, cast: cast)
        if info.path != nil {
            let (pos, heading) = pathAt(seconds, total: loop)
            let v = M3.rotY(view).apply(pos)
            s = s.moved(turning: heading, by: v)
            s.fxMove = (heading, v)
            if info.path?.grade != nil || info.path?.waveAmp != nil { s.floor = pos.y }
            // On rollers the bike follows the slope.
            if info.fixture != nil, info.path?.waveAmp != nil { s.fxPitch += atan(pathSlope(seconds, total: loop)) * 180 / .pi }
            for i in cast.indices where cast[i].follow { cast[i].s = cast[i].s.moved(turning: heading, by: v) }
        }
        s.cast = cast
        return s
    }
}

extension RigSkeleton {
    /// Turned `deg` about the vertical axis through the origin, then moved by `v`.
    func moved(turning deg: Double, by v: V3) -> RigSkeleton {
        let r = M3.rotY(deg)
        func t(_ p: V3) -> V3 { r.apply(p) + v }
        func limb(_ l: RigLimb) -> RigLimb {
            var o = l
            o.arm = r * l.arm; o.fore = r * l.fore; o.hand = r * l.hand; o.thigh = r * l.thigh; o.shin = r * l.shin; o.foot = r * l.foot
            o.footDir = r.apply(l.footDir)
            o.shoulder = t(l.shoulder); o.elbow = t(l.elbow); o.wrist = t(l.wrist); o.handTip = t(l.handTip)
            o.hip = t(l.hip); o.knee = t(l.knee); o.ankle = t(l.ankle); o.toe = t(l.toe); o.heel = t(l.heel)
            return o
        }
        var o = self
        o.root = r * root; o.trunk = r * trunk; o.chest = r * chest; o.headFrame = r * headFrame
        o.pelvis = t(pelvis); o.neckBase = t(neckBase); o.neckTop = t(neckTop); o.head = t(head)
        o.L = limb(L); o.R = limb(R)
        o.ball = ball.map(t)
        return o
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
