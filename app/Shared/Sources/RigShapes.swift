import SwiftUI

/// Turns a placed skeleton into flat, depth-sorted shapes — the body,
/// clothes, the red muscle glow, held equipment and fixtures. A port of
/// content/src/rigDraw.js (the preview renderer), shape for shape.
struct RigShape {
    var points: [CGPoint]
    var color: Color
    var opacity: Double = 1
    var depth: Double
    var stroke: Double? = nil
    var order: Int = 0
    /// The ball in play: drawn, but left out of the camera framing so a
    /// thrown ball simply flies out of the picture.
    var isBall = false
}

struct RigPalette {
    var skinNear, skinFar, shirtNear, shirtFar, shortsNear, shortsFar, shoe, hair, ground, steel, plate, wood, pad, water, glow, red: String
    var shadow: Color

    /// A cast member's kit (partner, passer, defender): lighter, so the
    /// athlete doing the drill stands out (rigDraw.js PARTNER).
    func partner(_ scheme: ColorScheme) -> RigPalette {
        var p = self
        if scheme == .dark {
            p.shirtNear = "#3A3F4C"; p.shirtFar = "#2A2E38"; p.shortsNear = "#4A505E"; p.shortsFar = "#353945"
        } else {
            p.shirtNear = "#9AA3B5"; p.shirtFar = "#7A8396"; p.shortsNear = "#6E7688"; p.shortsFar = "#555C6C"
        }
        p.hair = "#4A3525"
        return p
    }

    static func forScheme(_ scheme: ColorScheme) -> RigPalette {
        scheme == .dark
            ? RigPalette(skinNear: "#D9A47A", skinFar: "#A9764F", shirtNear: "#5C6272", shirtFar: "#3E4250", shortsNear: "#707688", shortsFar: "#4E5363",
                         shoe: "#E8E8EC", hair: "#2A1D15", ground: "#3A3A40", steel: "#B8BBC4", plate: "#D6D7DC", wood: "#C99A6A", pad: "#6A6E7A",
                         water: "#3F6E99", glow: "#FF4D4F", red: "#FF4D4F", shadow: .black.opacity(0.35))
            : RigPalette(skinNear: "#D9A47A", skinFar: "#A9764F", shirtNear: "#2B2D33", shirtFar: "#17181C", shortsNear: "#434957", shortsFar: "#272B33",
                         shoe: "#15161A", hair: "#2A1D15", ground: "#E3E3E8", steel: "#8E9199", plate: "#26272C", wood: "#B98A5A", pad: "#3A3D46",
                         water: "#9CC7F0", glow: "#E5383B", red: "#E5383B", shadow: .black.opacity(0.12))
    }
}

enum RigShapes {
    // MARK: 2D helpers

    static func hull(_ input: [CGPoint]) -> [CGPoint] {
        let p = input.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard p.count >= 3 else { return p }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        var lower: [CGPoint] = [], upper: [CGPoint] = []
        for q in p {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], q) <= 0 { lower.removeLast() }
            lower.append(q)
        }
        for q in p.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], q) <= 0 { upper.removeLast() }
            upper.append(q)
        }
        upper.removeLast(); lower.removeLast()
        return lower + upper
    }

    static func circle(_ c: CGPoint, _ r: Double, _ n: Int = 14) -> [CGPoint] {
        (0..<n).map { i in
            let a = Double(i) / Double(n) * .pi * 2
            return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        }
    }

    static func capsule(_ a: CGPoint, _ b: CGPoint, _ ra: Double, _ rb: Double) -> [CGPoint] {
        hull(circle(a, ra) + circle(b, rb))
    }

    static func halfCapsule(_ a: CGPoint, _ b: CGPoint, _ ra: Double, _ rb: Double, _ side: CGPoint) -> [CGPoint] {
        let l = max(hypot(side.x, side.y), 1e-9)
        let n = CGPoint(x: side.x / l, y: side.y / l)
        return [a, b, CGPoint(x: b.x + n.x * rb, y: b.y + n.y * rb), CGPoint(x: a.x + n.x * ra, y: a.y + n.y * ra)]
    }

    /// A long thin object (bar, stick, band, rope) as short pieces, each at
    /// its own depth, so hands and limbs pass in front of or behind it
    /// correctly along its length.
    static func segmented(_ a: V3, _ b: V3, _ ra: Double, _ rb: Double, _ color: Color, bias: Double = 0, n: Int = 10) -> [RigShape] {
        (0..<n).map { i in
            let t0 = Double(i) / Double(n), t1 = Double(i + 1) / Double(n)
            let p0 = a * (1 - t0) + b * t0, p1 = a * (1 - t1) + b * t1
            return RigShape(points: capsule(P(p0), P(p1), ra + (rb - ra) * t0, ra + (rb - ra) * t1), color: color, depth: (D(p0) + D(p1)) / 2 + bias)
        }
    }
    /// Hands sit on top of whatever they grip.
    static let gripBias = 0.6

    static func P(_ p: V3) -> CGPoint { RigProjection.point(p) }
    static func D(_ p: V3) -> Double { RigProjection.depth(p) }
    static func dir2(_ v: V3) -> CGPoint { RigProjection.point(v) }
    static func facing(_ v: V3) -> Double { RigProjection.depth(normed(v)) }

    static func mix(_ a: String, _ b: String, _ t: Double) -> Color {
        func rgb(_ hex: String) -> (Double, Double, Double) {
            let n = Int(hex.dropFirst(), radix: 16) ?? 0
            return (Double((n >> 16) & 255), Double((n >> 8) & 255), Double(n & 255))
        }
        let x = rgb(a), y = rgb(b), k = min(max(t, 0), 1)
        let r = (x.0 + (y.0 - x.0) * k).rounded(), g = (x.1 + (y.1 - x.1) * k).rounded(), bl = (x.2 + (y.2 - x.2) * k).rounded()
        return Color(red: r / 255, green: g / 255, blue: bl / 255)
    }
    static func shade(_ far: String, _ near: String, _ depth: Double) -> Color { mix(far, near, (depth + 13) / 26) }

    /// Ball colours by name (as content/src/rigDraw.js BALL_COLORS).
    static let ballColors: [String: String] = ["orange": "#E8762B", "white": "#F4F4F2", "yellow": "#D8E83A", "red": "#E5383B",
                                               "brown": "#8B4A2B", "blue": "#2F6FE0", "black": "#1E1E22"]

    static let torso: [(t: Double, w: Double, f: Double, b: Double)] = [
        (0, 13.5, 8, 9.5), (0.18, 12.8, 9, 8.6), (0.45, 12.2, 8, 7.6), (0.72, 15, 10.2, 9), (0.9, 16, 8.8, 9.4), (1, 9, 5, 5.5),
    ]

    static func disc(_ centre: V3, _ normal: V3, _ r: Double, _ n: Int = 18) -> [CGPoint] {
        let nn = normed(normal)
        let helper = abs(nn.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)
        let u = normed(nn.cross(helper)), v = nn.cross(u)
        return (0..<n).map { i in
            let a = Double(i) / Double(n) * .pi * 2
            return P(centre + u * (cos(a) * r) + v * (sin(a) * r))
        }
    }
    static func sphere(_ c: V3, _ r: Double) -> [CGPoint] { circle(P(c), r, 18) }

    // MARK: The figure

    /// The whole scene: the athlete plus any cast. Each person is drawn whole,
    /// far to near; every floor shadow first; the ball sorted into the nearest
    /// person's shapes (rigDraw.js sceneShapes).
    static func scene(_ s: RigSkeleton, playback: RigPlayback, glow: [String: Double], palette pal: RigPalette, scheme: ColorScheme = .light) -> [RigShape] {
        var groups: [(pelvis: V3, shapes: [RigShape])] = [(s.pelvis, shapes(s, playback: playback, glow: glow, palette: pal, withBall: false))]
        for m in s.cast {
            var member = shapes(m.s, playback: m.playback, glow: [:], palette: pal.partner(scheme), withBall: false, withFixture: false)
            if m.tether {
                // A guide's tether: a short cord from the athlete's left hand to the guide's right.
                let a = s.L.wrist, b = m.s.R.wrist
                let sag = (a + b) / 2 + V3(0, -6, 0)
                member.append(RigShape(points: capsule(P(a), P(sag), 0.7, 0.7), color: Color(hex: pal.red), depth: (D(a) + D(sag)) / 2 + 0.5))
                member.append(RigShape(points: capsule(P(sag), P(b), 0.7, 0.7), color: Color(hex: pal.red), depth: (D(sag) + D(b)) / 2 + 0.5))
            }
            groups.append((m.s.pelvis, member))
        }
        if let ball = s.ball, let spec = playback.info.ball {
            let depth = D(ball) + spec.r * 0.5
            var balls: [RigShape] = []
            if spec.shape == "arrow" {
                // An arrow in flight, pointing along its path (forward).
                let fw = normed(V3(s.root.apply(V3(1, 0, 0)).x, 0, s.root.apply(V3(1, 0, 0)).z))
                balls.append(RigShape(points: capsule(P(ball - fw * 30), P(ball + fw * 30), 0.6, 0.6), color: Color(hex: pal.red), depth: depth, isBall: true))
            } else if spec.shape == "shuttle" {
                // A shuttlecock: the cork, and the feather skirt flaring up from it.
                balls.append(RigShape(points: hull([P(ball), P(ball + V3(-spec.r * 2.2, spec.r * 3.8, 0)), P(ball + V3(spec.r * 2.2, spec.r * 3.8, 0))]),
                                      color: Color(hex: "#E9E9EE"), depth: depth - 0.01, isBall: true))
                balls.append(RigShape(points: sphere(ball, spec.r), color: Color(hex: ballColors["white"] ?? "#F4F4F2"), depth: depth, isBall: true))
            } else if spec.shape == "puck" {
                // A hockey puck: a flat black disc lying on the ice.
                balls.append(RigShape(points: hull(disc(ball + V3(0, 1 - spec.r, 0), V3(0, 1, 0), spec.r, 14)), color: Color(hex: pal.shoe), depth: depth, isBall: true))
            } else if spec.shape == "disc" {
                // A flying disc: flat, tilted slightly.
                balls.append(RigShape(points: hull(disc(ball, normed(V3(0, 1, 0) + s.root.apply(V3(0, 0, 1)) * 0.2), 10.5, 18)),
                                      color: Color(hex: ballColors[spec.color] ?? pal.red), depth: depth, isBall: true))
            } else if spec.shape == "flag" {
                // A tossed color-guard flag: pole upright and turning, silk at the top.
                let up = normed(V3(0, 1, 0) + s.root.apply(V3(1, 0, 0)) * 0.25)
                // The silk angles between forward and sideways so it reads from any camera.
                let fw = normed(V3(s.root.apply(V3(1, 0, 0)).x, 0, s.root.apply(V3(1, 0, 0)).z) + s.root.apply(V3(0, 0, 1)))
                let lo = ball - up * 20, top = ball + up * 150
                // A tossed flag stays in the camera framing (unlike a thrown ball).
                balls.append(RigShape(points: capsule(P(lo), P(top), 1.1, 1.1), color: Color(hex: pal.steel), depth: depth))
                balls.append(RigShape(points: hull([P(top), P(top - up * 56), P(top - up * 56 + fw * 44), P(top + fw * 44)]),
                                      color: Color(hex: pal.red), opacity: 0.9, depth: depth + 0.01))
            } else if spec.shape == "baton" {
                // A relay baton: a short tube standing up in the hand.
                let up = normed(V3(0, 1, 0) + s.root.apply(V3(1, 0, 0)) * 0.35)
                balls.append(RigShape(points: capsule(P(ball - up * 14), P(ball + up * 14), 1.9, 1.9), color: Color(hex: ballColors[spec.color] ?? pal.red), depth: depth, isBall: true))
            } else if spec.color == "white" {
                balls.append(RigShape(points: sphere(ball, spec.r + 0.5), color: Color(hex: "#8A8A90"), depth: depth - 0.001, isBall: true))
            }
            if spec.shape == nil {
                balls.append(RigShape(points: sphere(ball, spec.r), color: Color(hex: ballColors[spec.color] ?? pal.red), depth: depth, isBall: true))
            }
            func dist(_ p: V3) -> Double { hypot(p.x - ball.x, p.z - ball.z) }
            let near = groups.indices.min { dist(groups[$0].pelvis) < dist(groups[$1].pelvis) } ?? 0
            let at = groups[near].shapes.firstIndex { $0.depth > depth } ?? groups[near].shapes.count
            groups[near].shapes.insert(contentsOf: balls, at: at)
        }
        if groups.count == 1 { return groups[0].shapes }
        groups.sort { D($0.pelvis) < D($1.pelvis) }
        let all = groups.flatMap(\.shapes)
        return all.filter { $0.depth <= -1e5 } + all.filter { $0.depth > -1e5 }
    }

    /// One person's shapes for one frame, far to near.
    static func shapes(_ s: RigSkeleton, playback: RigPlayback, glow: [String: Double], palette pal: RigPalette,
                       withBall: Bool = true, withFixture: Bool = true) -> [RigShape] {
        var shapes: [RigShape] = []
        var glowOverlays: [Int: (points: [CGPoint], alpha: Double)] = [:]
        func push(_ points: [CGPoint], _ color: Color, _ depth: Double, opacity: Double = 1, stroke: Double? = nil) {
            shapes.append(RigShape(points: points, color: color, opacity: opacity, depth: depth, stroke: stroke, order: shapes.count))
        }
        func pushGlowing(_ points: [CGPoint], _ color: Color, _ depth: Double, glowPoly: [CGPoint]?, alpha: Double) {
            push(points, color, depth)
            if let glowPoly, alpha > 0 { glowOverlays[shapes.count - 1] = (glowPoly, alpha) }
        }

        // Shadow on the floor.
        if playback.info.fixture?.kind != "water" {
            let feet = [s.L.toe, s.L.heel, s.R.toe, s.R.heel, s.pelvis, s.L.wrist, s.R.wrist]
            let xs = feet.map { P(V3($0.x, s.floor, $0.z)).x }
            let minX = (xs.min() ?? 0) - 6, maxX = (xs.max() ?? 0) + 6
            let lowest = (feet.map(\.y).min() ?? 0) - s.floor
            if lowest < 30 {
                let k = max(0.25, 1 - lowest / 40)
                let cx = (minX + maxX) / 2, rx = (maxX - minX) / 2, cy = P(V3(0, s.floor, 0)).y
                let pts = (0..<20).map { i -> CGPoint in
                    let a = Double(i) / 20 * .pi * 2
                    return CGPoint(x: cx + cos(a) * rx, y: cy + sin(a) * 2.4 * k)
                }
                shapes.append(RigShape(points: pts, color: pal.shadow, depth: -1e6, order: shapes.count))
            }
        }

        if withFixture, let fx = playback.fixture { shapes += fixtureShapes(s, fx, pal) }

        // Torso slices.
        struct SlicePoint { var world: V3; var front: Double }
        let slices: [(t: Double, pts: [SlicePoint])] = torso.map { row in
            let up = s.trunk.apply(V3(0, 1, 0))
            let centre = s.pelvis + up * (RigBones.torso * row.t) + s.trunk.apply(V3((row.f - row.b) / 2, 0, 0))
            let twisted = s.trunk * M3.rotY(s.twist * row.t)
            let pts = (0..<18).map { i -> SlicePoint in
                let a = Double(i) / 18 * .pi * 2
                let local = V3(sin(a) * (row.f + row.b) / 2, 0, cos(a) * row.w)
                return SlicePoint(world: centre + twisted.apply(local), front: sin(a))
            }
            return (row.t, pts)
        }
        let torsoDepth = (D(s.pelvis) + D(s.neckBase)) / 2 - 2
        let shirt = shade(pal.shirtFar, pal.shirtNear, torsoDepth + 8)
        for i in 0..<(slices.count - 1) {
            push(hull((slices[i].pts + slices[i + 1].pts).map { P($0.world) }), shirt, torsoDepth)
        }
        push(hull((slices[0].pts + slices[1].pts).map { P(s.pelvis + ($0.world - s.pelvis) * 1.05) }),
             shade(pal.shortsFar, pal.shortsNear, torsoDepth + 8), torsoDepth + 0.01)

        let trunkFwd = s.trunk.apply(V3(1, 0, 0))
        func torsoGlow(_ region: String, _ t0: Double, _ t1: Double, front: Bool) {
            guard let o = glow[region], o > 0 else { return }
            let f = facing(trunkFwd) * (front ? 1 : -1)
            let alpha = o * 0.85 * (0.4 + 0.6 * max(0, f + 0.35))
            var pts: [CGPoint] = []
            for sl in slices where sl.t >= t0 - 1e-6 && sl.t <= t1 + 1e-6 {
                for p in sl.pts where front ? p.front > -0.05 : p.front < 0.05 { pts.append(P(p.world)) }
            }
            if pts.count >= 3 { push(hull(pts), Color(hex: pal.glow), torsoDepth + 0.02, opacity: alpha) }
        }
        torsoGlow("chest", 0.6, 0.95, front: true)
        torsoGlow("abs", 0.12, 0.6, front: true)
        torsoGlow("upperBack", 0.5, 0.95, front: false)
        torsoGlow("lowerBack", 0.12, 0.5, front: false)
        torsoGlow("glutes", 0, 0.2, front: false)

        // Neck, head, hair, ear.
        let neckShape = capsule(P(s.neckBase), P(s.neckTop), 4.4, 4.1)
        pushGlowing(neckShape, shade(pal.skinFar, pal.skinNear, D(s.neckTop) + 6), torsoDepth + 0.5, glowPoly: neckShape, alpha: (glow["neck"] ?? 0) * 0.85)
        let headUp = s.headFrame.apply(V3(0, 1, 0)), headFwd = s.headFrame.apply(V3(1, 0, 0))
        let hairC = s.head + headUp * 1.6 - headFwd * 1.7
        let faceC = s.head - headUp * 0.8 + headFwd * 1.2
        let hairShape = circle(P(hairC), RigBones.headR + 0.4, 24), faceShape = circle(P(faceC), RigBones.headR - 0.6, 24)
        let headDepth = D(s.head) + 1
        let skinHead = shade(pal.skinFar, pal.skinNear, D(faceC) + 8)
        if facing(headFwd) >= -0.35 {
            push(hairShape, Color(hex: pal.hair), headDepth)
            push(faceShape, skinHead, headDepth + 0.001)
        } else {
            push(faceShape, skinHead, headDepth)
            push(hairShape, Color(hex: pal.hair), headDepth + 0.001)
        }
        // Headwear: goalball eyeshades, a bike helmet.
        let wear = playback.info.wear ?? []
        if wear.contains("helmet") {
            let faceY = P(faceC).y
            let dome = circle(P(hairC + headUp * 1.2), RigBones.headR + 1.6, 28).filter { $0.y <= faceY + 1 }
            if dome.count >= 3 { push(hull(dome), Color(hex: pal.red), headDepth + 0.004) }
        }
        if wear.contains("eyeshade"), facing(headFwd) > -0.5 {
            let lat = s.headFrame.apply(V3(0, 0, 1))
            let eye = s.head + headFwd * (RigBones.headR - 1.2) + headUp * 0.6
            push(capsule(P(eye - lat * 5.8), P(eye + lat * 5.8), 2.4, 2.4), Color(hex: "#1E1E22"), headDepth + 0.003)
        }
        for σ in [1.0, -1.0] {
            let lat = s.headFrame.apply(V3(0, 0, σ))
            guard facing(lat) >= 0.2 else { continue }
            let ear = s.head + lat * (RigBones.headR - 1) - headFwd * 0.8
            push(circle(P(ear), 1.9, 10), mix(pal.skinFar, pal.skinNear, 0.7), D(ear) + 1.2)
        }

        // Limbs.
        for (side, l) in [("L", s.L), ("R", s.R)] {
            let blade = playback.info.prosthetic == side
            func d(_ p: V3, _ q: V3) -> Double { (D(p) + D(q)) / 2 }
            func skin(_ depth: Double) -> Color { shade(pal.skinFar, pal.skinNear, depth) }
            let thighD = d(l.hip, l.knee), shinD = d(l.knee, l.ankle)
            let thigh = capsule(P(l.hip), P(l.knee), 8.2, 5.4)
            let tg = limbGlow(glow, l.thigh, l.hip, l.knee, 8.2, 5.4, ["thighFront", "thighBack", "thigh"])
            pushGlowing(thigh, skin(thighD), thighD, glowPoly: tg?.0, alpha: tg?.1 ?? 0)
            if blade {
                // A below-knee running blade: socket, then a carbon C-curve to the toe.
                let down = normed(l.ankle - l.knee), back = normed(l.heel - l.toe)
                let socket = l.knee + down * 16
                let bend = l.ankle + back * 7 - down * 4
                push(capsule(P(l.knee), P(socket), 5.4, 4.2), Color(hex: pal.steel), shinD + 0.02)
                push(capsule(P(socket), P(bend), 2.2, 2.0), Color(hex: pal.plate), shinD + 0.01)
                push(capsule(P(bend), P(l.toe + V3(0, 1, 0)), 2.0, 1.6), Color(hex: pal.plate), d(l.ankle, l.toe))
                let shortsEnd = l.hip + l.thigh.apply(V3(0, -1, 0)) * (RigBones.thigh * 0.55)
                push(capsule(P(l.hip), P(shortsEnd), 9.2, 7), shade(pal.shortsFar, pal.shortsNear, thighD), thighD + 0.01)
            } else {
            let calfC = l.knee + l.shin.apply(V3(0, -1, 0)) * (RigBones.shin * 0.33) + l.shin.apply(V3(-1, 0, 0)) * 2.2
            let shinShape = hull(capsule(P(l.knee), P(l.ankle), 5.2, 3.2) + circle(P(calfC), 4.6))
            let sg = limbGlow(glow, l.shin, l.knee, l.ankle, 5.2, 3.2, ["shinFront", "shinBack", ""])
            pushGlowing(shinShape, skin(shinD), shinD, glowPoly: sg?.0, alpha: sg?.1 ?? 0)
            let shortsEnd = l.hip + l.thigh.apply(V3(0, -1, 0)) * (RigBones.thigh * 0.55)
            push(capsule(P(l.hip), P(shortsEnd), 9.2, 7), shade(pal.shortsFar, pal.shortsNear, thighD), thighD + 0.01)
            // Shoe.
            let fd = l.footDir
            let fl = normed(l.foot.apply(V3(0, 0, 1)))
            let fup = l.foot.apply(V3(0, 1, 0))
            let fu = normed(fup - fd * (fup).dot(fd))
            var box: [CGPoint] = []
            for (along, upv, w) in [(-RigBones.heel - 0.5, 0.0, 3.6), (RigBones.foot + 0.8, 0, 3.2), (-RigBones.heel, 5.5, 3.4), (2, 6.4, 3.6), (RigBones.foot - 1, 2.6, 3.2), (RigBones.foot + 0.6, 1.2, 3)] {
                for σ in [1.0, -1.0] { box.append(P(l.ankle + fd * along + fu * upv + fl * (σ * w))) }
            }
            let shoe = hull(box)
            pushGlowing(shoe, Color(hex: pal.shoe), D(l.ankle + fd * 5), glowPoly: shoe, alpha: (glow["foot"] ?? 0) * 0.6)
            }
            // Arm.
            let upperD = d(l.shoulder, l.elbow), foreD = d(l.elbow, l.wrist)
            let ug = limbGlow(glow, l.arm, l.shoulder, l.elbow, 5, 3.9, ["upperArmFront", "upperArmBack", ""])
            pushGlowing(capsule(P(l.shoulder), P(l.elbow), 5, 3.9), skin(upperD), upperD, glowPoly: ug?.0, alpha: ug?.1 ?? 0)
            let sleeveEnd = l.shoulder + l.arm.apply(V3(0, -1, 0)) * (RigBones.upperArm * 0.42)
            pushGlowing(capsule(P(l.shoulder), P(sleeveEnd), 5.7, 4.8), shade(pal.shirtFar, pal.shirtNear, upperD), upperD + 0.01,
                        glowPoly: circle(P(l.shoulder), 5.8), alpha: (glow["shoulderCap"] ?? 0) * 0.85)
            let fore = capsule(P(l.elbow), P(l.wrist), 3.8, 2.7)
            pushGlowing(fore, skin(foreD), foreD, glowPoly: fore, alpha: (glow["forearm"] ?? 0) * 0.85)
            let handC = l.wrist + l.hand.apply(V3(0, -1, 0)) * (RigBones.hand * 0.45)
            push(capsule(P(l.wrist), P(handC), 2.8, 3.2), skin(D(handC)), D(handC) + gripBias)
        }

        if let spec = playback.info.implement {
            shapes += implementShapes(s, spec, pal)
        }
        if withBall, let ball = s.ball, let spec = playback.info.ball {
            let depth = D(ball) + spec.r * 0.5
            if spec.color == "white" {
                shapes.append(RigShape(points: sphere(ball, spec.r + 0.5), color: Color(hex: "#8A8A90"), depth: depth - 0.001, isBall: true))
            }
            shapes.append(RigShape(points: sphere(ball, spec.r), color: Color(hex: ballColors[spec.color] ?? pal.red), depth: depth, isBall: true))
        }

        // Far to near (stable), each glow straight after its base shape.
        let sorted = shapes.enumerated().sorted { a, b in
            a.element.depth != b.element.depth ? a.element.depth < b.element.depth : a.offset < b.offset
        }
        var out: [RigShape] = []
        out.reserveCapacity(shapes.count + glowOverlays.count)
        for (index, sh) in sorted {
            out.append(sh)
            if let g = glowOverlays[index] {
                out.append(RigShape(points: g.points, color: Color(hex: pal.glow), opacity: g.alpha, depth: sh.depth))
            }
        }
        return out
    }

    /// A limb's red overlay: the half on the muscle's side (front/back), or
    /// the whole segment when seen end-on, fading as it turns away.
    static func limbGlow(_ glow: [String: Double], _ frame: M3, _ a: V3, _ b: V3, _ ra: Double, _ rb: Double, _ keys: [String]) -> ([CGPoint], Double)? {
        let anterior = frame.apply(V3(1, 0, 0))
        let pa = P(a), pb = P(b)
        let side2 = dir2(anterior)
        let sideLen = hypot(side2.x, side2.y)
        var best: ([CGPoint], Double)?
        for (key, sign) in [(keys[0], 1.0), (keys[1], -1.0)] {
            guard !key.isEmpty, let o = glow[key], o > 0 else { continue }
            let f = facing(anterior) * sign
            let alpha = o * 0.85 * (0.45 + 0.55 * max(0, f + 0.4))
            let poly = sideLen > 0.35 ? halfCapsule(pa, pb, ra, rb, CGPoint(x: side2.x * sign, y: side2.y * sign)) : capsule(pa, pb, ra, rb)
            if best == nil || alpha > best!.1 { best = (poly, alpha) }
        }
        if keys[2] != "", let o = glow[keys[2]], o > 0, best == nil || o * 0.85 > best!.1 {
            best = (capsule(pa, pb, ra, rb), o * 0.85)
        }
        return best
    }

    // MARK: Implements

    static func implementPoint(_ s: RigSkeleton, _ at: String) -> V3 {
        let fwd = s.chest.apply(V3(1, 0, 0)), up = s.trunk.apply(V3(0, 1, 0))
        func grip(_ l: RigLimb) -> V3 { l.wrist + l.hand.apply(V3(0, -1, 0)) * 3.5 }
        switch at {
        case "back": return s.neckBase - up * 4 - fwd * 8.5
        case "rack": return s.neckBase - up * 5 + fwd * 9
        case "chest": return (grip(s.L) + grip(s.R)) / 2
        case "hips": return s.pelvis + s.trunk.apply(V3(1, 0, 0)) * 11
        case "knees": return (s.L.knee + s.R.knee) / 2
        case "L": return grip(s.L)
        case "R": return grip(s.R)
        case "footL": return s.L.toe + V3(4, 4.5, 0)
        case "footR": return s.R.toe + V3(4, 4.5, 0)
        default: return (grip(s.L) + grip(s.R)) / 2
        }
    }

    static func implementShapes(_ s: RigSkeleton, _ spec: RigImplementSpec, _ pal: RigPalette) -> [RigShape] {
        var out: [RigShape] = []
        func push(_ points: [CGPoint], _ hex: String, _ depth: Double) { out.append(RigShape(points: points, color: Color(hex: hex), depth: depth)) }
        let lateral = s.chest.apply(V3(0, 0, 1))
        let at = implementPoint(s, spec.at)
        func handDir(_ l: RigLimb) -> V3 { l.hand.apply(V3(0, -1, 0)) }
        let rootFwd = s.root.apply(V3(1, 0, 0))
        let fwFlat = normed(V3(rootFwd.x, 0, rootFwd.z))
        let rootLat = s.root.apply(V3(0, 0, 1))
        let azFlat = normed(V3(rootLat.x, 0, rootLat.z))
        let one = spec.at == "R" ? s.R : s.L
        let oneGrip = implementPoint(s, spec.at == "R" ? "R" : "L")

        switch spec.kind {
        case "barbell" where spec.flags.contains("trap"):
            // Trap (hex) bar: a hexagonal frame around the lifter, side handles, sleeves out left and right.
            let fwdT = normed(V3(s.root.apply(V3(1, 0, 0)).x, 0, s.root.apply(V3(1, 0, 0)).z))
            let gL = implementPoint(s, "L"), gR = implementPoint(s, "R")
            let mid = (gL + gR) * 0.5
            let side = normed(gL - gR)
            let w = max(18, (gL - gR).length / 2)
            let hex: [V3] = [(-22.0, w + 6), (0, w + 12), (22, w + 6), (22, -(w + 6)), (0, -(w + 12)), (-22, -(w + 6))]
                .map { mid + fwdT * $0.0 + side * $0.1 }
            for i in 0..<6 { out += segmented(hex[i], hex[(i + 1) % 6], 1.1, 1.1, Color(hex: pal.steel), n: 3) }
            for σ in [1.0, -1.0] {
                out += segmented(mid + side * (σ * (w + 12)), mid + side * (σ * (w + 30)), 1.1, 1.1, Color(hex: pal.steel), n: 3)
                let c = mid + side * (σ * (w + 22))
                push(hull(disc(c, side, 12)), pal.plate, D(c) + (σ > 0 ? 0 : -0.1))
            }
        case "barbell":
            out += segmented(at + lateral * 52, at - lateral * 52, 1.1, 1.1, Color(hex: pal.steel), n: 14)
            // pvc: a light pipe for technique work — no plates.
            for σ in spec.flags.contains("pvc") ? [] : [1.0, -1.0] {
                for off in [34.0, 38.0] {
                    let c = at + lateral * (σ * off)
                    push(hull(disc(c, lateral, off == 34 ? 12 : 10)), pal.plate, D(c) + (σ > 0 ? 0 : -0.1))
                }
            }
        case "dumbbell", "dumbbells":
            let hands = spec.kind == "dumbbells" ? ["L", "R"] : [spec.at == "R" ? "R" : "L"]
            for h in hands {
                let g = implementPoint(s, h)
                let ax = s.limb(h).hand.apply(V3(0, 0, 1))
                push(capsule(P(g + ax * 7), P(g - ax * 7), 1.2, 1.2), pal.steel, D(g) + 0.3)
                for σ in [1.0, -1.0] { push(hull(disc(g + ax * (σ * 7.5), ax, 4.6, 8)), pal.plate, D(g + ax * (σ * 7.5)) + 0.3) }
            }
        case "goblet":
            let upv = s.trunk.apply(V3(0, 1, 0))
            let c = at + upv * 4
            push(capsule(P(c + upv * 7), P(c - upv * 7), 1.3, 1.3), pal.steel, D(at) + 0.6)
            for σ in [1.0, -1.0] { push(hull(disc(c + upv * (σ * 7.5), upv, 5.2, 12)), pal.plate, D(at) + 0.61) }
        case "kettlebell":
            let c = at + V3(0, -7, 0)
            push(sphere(c, 6.4), pal.plate, D(c) + 0.4)
            push(capsule(P(at), P(at + V3(0, -2, 0)), 2.4, 2.4), pal.plate, D(at) + 0.4)
        case "medball":
            let c = at + s.chest.apply(V3(1, 0, 0)) * 5
            push(sphere(c, 7.5), pal.red, D(c) + 0.6)
        case "plate":
            push(hull(disc(at, s.chest.apply(V3(1, 0, 0)), 11)), pal.plate, D(at) + 0.6)
        case "ball", "football":
            let c = spec.at.hasPrefix("foot") ? at : at + s.chest.apply(V3(1, 0, 0)) * 4
            push(sphere(c, spec.kind == "football" ? 5 : 5.6), pal.red, D(c) + 0.7)
        case "puck":
            let c = s.L.toe + V3(10, 0.8, 0)
            push(hull(disc(c, V3(0, 1, 0), 3.2, 10)), pal.shoe, D(c))
        case "bat", "club", "stick", "racket", "paddle", "javelin", "pole", "lacrosse", "bow", "oar":
            let lengths: [String: Double] = ["bat": 48, "club": 58, "stick": 56, "racket": 30, "paddle": 20, "javelin": 70, "pole": 62, "lacrosse": 50, "bow": 40, "oar": 60]
            let along = spec.kind == "javelin" || spec.kind == "pole" ? normed(handDir(one) + one.hand.apply(V3(1, 0, 0)) * 0) : handDir(one)
            let dir = spec.kind == "bow" ? s.chest.apply(V3(0, 1, 0)) : normed(along + one.fore.apply(V3(0, -1, 0)) * 0.6)
            let start = spec.kind == "javelin" ? oneGrip - dir * 30 : oneGrip
            let tip = oneGrip + dir * (lengths[spec.kind] ?? 50)
            let thick = spec.kind == "bat" ? (1.4, 2.8) : (1.1, 1.3)
            out += segmented(start, tip, thick.0, thick.1, Color(hex: spec.kind == "bat" ? pal.wood : pal.red), n: 8)
            if spec.kind == "racket" || spec.kind == "paddle" {
                let head = oneGrip + dir * ((lengths[spec.kind] ?? 30) + (spec.kind == "racket" ? 9 : 6))
                push(hull(disc(head, one.hand.apply(V3(1, 0, 0)), spec.kind == "racket" ? 10 : 7, 16)), pal.red, D(oneGrip) + 0.81)
            }
            if spec.kind == "stick" || spec.kind == "club" {
                push(capsule(P(tip), P(tip + fwFlat * 9), 1.6, 1.6), pal.red, D(oneGrip) + 0.8)
            }
        case "disc":
            let n = one.hand.apply(V3(1, 0, 0))
            push(hull(disc(oneGrip + n * 3, n, 10.5, 18)), pal.red, D(oneGrip) + 0.8)
        case "shot":
            let g = implementPoint(s, spec.at == "R" ? "R" : (spec.at == "L" ? "L" : "hands"))
            push(sphere(g, 4.8), pal.plate, D(g) + 0.8)
        case "rifle", "sword":
            let dir = spec.kind == "rifle" ? normed(one.fore.apply(V3(0, -1, 0))) : normed(handDir(one) + one.fore.apply(V3(0, -1, 0)))
            let back = spec.kind == "rifle" ? 22.0 : 2, fwdLen = spec.kind == "rifle" ? 38.0 : 52
            push(capsule(P(oneGrip - dir * back), P(oneGrip + dir * fwdLen), spec.kind == "rifle" ? 2.2 : 0.8, spec.kind == "rifle" ? 1.2 : 0.6),
                 spec.kind == "rifle" ? pal.plate : pal.steel, D(oneGrip) + 0.8)
            if spec.kind == "sword" { push(hull(disc(oneGrip + dir * 2, dir, 4, 12)), pal.steel, D(oneGrip) + 0.81) }
        case "glove":
            push(circle(P(oneGrip), 5.4, 16), pal.wood, D(oneGrip) + 0.9)
        case "board":
            let mid = (s.L.ankle + s.R.ankle) / 2
            let along = normed(s.R.ankle - s.L.ankle)
            push(capsule(P(mid + along * 38 + V3(0, -2, 0)), P(mid - along * 38 + V3(0, -2, 0)), 2.2, 2.2), pal.red, min(D(s.L.ankle), D(s.R.ankle)) - 0.5)
        case "band", "cable":
            let hex = spec.kind == "band" ? pal.red : pal.steel
            if spec.flags.contains("toFootL") || spec.flags.contains("toFootR") {
                // A band from the hands round one foot (hamstring floss, stretches).
                let l = s.limb(spec.flags.contains("toFootL") ? "L" : "R")
                out += segmented(implementPoint(s, "hands"), (l.ankle + l.toe) * 0.5, 0.9, 0.9, Color(hex: hex), n: 10)
            } else if spec.flags.contains("loopFeet") {
                // An assistance band looped from the hands (on the bar) to the feet.
                out += segmented(implementPoint(s, "hands"), (s.L.ankle + s.R.ankle) * 0.5, 0.9, 0.9, Color(hex: hex), n: 10)
            } else if spec.flags.contains("underFeet") || spec.flags.contains("underHands") {
                // Standing on the band (ends in the hands), or held down on the floor by the hands.
                let feet = (s.L.ankle + s.R.ankle) * 0.5
                for side in ["L", "R"] {
                    let g = implementPoint(s, side)
                    let ankle = s.limb(side).ankle
                    let floor = spec.flags.contains("underFeet")
                        ? V3(feet.x + (ankle.x - feet.x) * 0.5, 0.8, feet.z + (ankle.z - feet.z) * 0.5)
                        : V3(g.x, 0.8, g.z)
                    out += segmented(g, floor, 0.8, 0.8, Color(hex: hex), n: 8)
                }
            } else if let to = spec.to {
                let base = (s.L.ankle + s.R.ankle) / 2
                let target = V3(base.x, 0, base.z) + fwFlat * to[0] + V3(0, to[1], 0) + azFlat * (to.count > 2 ? to[2] : 0)
                out += segmented(at, target, 0.8, 0.8, Color(hex: hex), n: 10)
                if spec.kind == "cable" { push(circle(P(target), 3, 10), pal.steel, D(target) - 0.3) }
            } else {
                let a = implementPoint(s, "L"), b = implementPoint(s, "R")
                out += segmented(a, b, 0.9, 0.9, Color(hex: hex), n: 8)
            }
        case "landmine":
            let pivot = V3(oneGrip.x, 0, oneGrip.z) + fwFlat * 95
            let axis = normed(oneGrip - pivot)
            out += segmented(oneGrip, pivot, 1.3, 1.1, Color(hex: pal.steel), n: 10)
            push(hull(disc(oneGrip - axis * 6, axis, 10, 16)), pal.plate, D(oneGrip) + 0.49)
        case "hockeystick":
            let leftTop = spec.flags.contains("leftTop")
            let top = implementPoint(s, leftTop ? "L" : "R"), bottom = implementPoint(s, leftTop ? "R" : "L")
            let dir = normed(bottom - top)
            let length = spec.numbers["length"] ?? 128
            let toIce = dir.y < -0.15 ? (top.y - 1) / -dir.y : .infinity
            let heel = top + dir * min(length - 10, toIce)
            out += segmented(top - dir * 6, heel, 1.3, 1.1, Color(hex: pal.plate), n: 10)
            let bladeDir = normed(fwFlat - dir * (fwFlat).dot(dir))
            push(capsule(P(heel), P(heel + bladeDir * 16), 1.6, 1.4), pal.plate, D(heel) + 0.6)
            if spec.flags.contains("puck") {
                let puck = heel + bladeDir * 9 + fwFlat * 5
                if spec.flags.contains("ball") { push(sphere(V3(puck.x, 3.6, puck.z), 3.6), pal.red, D(puck) + 0.5) }
                else { push(hull(disc(V3(puck.x, 1, puck.z), V3(0, 1, 0), 3.4, 12)), pal.shoe, D(puck) + 0.5) }
            }
        case "lacrosse2":
            let lo = implementPoint(s, "L"), hi = implementPoint(s, "R")
            let dir = normed(hi - lo)
            let face = normed(fwFlat - dir * fwFlat.dot(dir))
            let reachHead = spec.numbers["head"] ?? RigBones.lacrosseHead
            out += segmented(lo + dir * (reachHead - 104), lo + dir * (reachHead - 7), 1.2, 1.2, Color(hex: pal.plate), n: 10)
            let head = lo + dir * reachHead
            push(hull(disc(head, face, 7.5, 16)), pal.steel, D(head) + 0.4)
            push(hull(disc(head + face * 0.4, face, 5.8, 16)), pal.plate, D(head) + 0.41)
        case "bat2":
            let lo = implementPoint(s, "L"), hi = implementPoint(s, "R")
            let dir = normed(hi - lo)
            out += segmented(lo - dir * 3, lo + dir * 62, 1.3, 2.9, Color(hex: pal.wood), n: 8)
        case "wheel":
            let c = implementPoint(s, "hands") + V3(0, -3, 0)
            push(hull(disc(c, lateral, 7, 18)), pal.plate, D(c) + 0.6)
            push(capsule(P(c + lateral * 11), P(c - lateral * 11), 1.2, 1.2), pal.steel, D(c) + 0.61)
        case "oar2":
            // A sweep oar: both hands on the handle, the shaft through the pin on the rigger, the blade out over the water.
            let handle = (implementPoint(s, "L") + implementPoint(s, "R")) / 2
            let pin = s.pelvis + s.root.apply(V3(1, 0, 0)) * 8 + V3(0, 12, 0) + s.root.apply(V3(0, 0, -1)) * 70
            let dir = normed(pin - handle)
            let tip = handle + dir * 260
            push(capsule(P(handle - dir * 10), P(tip), 1.2, 1.2), pal.steel, D(pin) - 0.2)
            push(capsule(P(tip - dir * 40), P(tip), 4.5, 4.5), pal.red, D(tip) - 0.1)
        case "skateboard":
            // Deck between the feet (it tilts with them), trucks and wheels underneath.
            let mid = (s.L.toe + s.R.heel) / 2
            let along = normed(s.L.toe - s.R.heel)
            push(capsule(P(mid + along * 42 - V3(0, 2.5, 0)), P(mid - along * 42 - V3(0, 2.5, 0)), 2, 2), pal.plate, min(D(s.L.ankle), D(s.R.ankle)) - 0.5)
            for k in [28.0, -28.0] {
                let w = mid + along * k - V3(0, 6.5, 0)
                push(circle(P(w), 3, 10), pal.steel, D(w) - 0.6)
            }
        case "skis":
            // A ski under each foot along the foot (long in front), and poles when asked.
            for l in [s.L, s.R] {
                let fd = normed(l.footDir)
                let sole = l.ankle - V3(0, 6, 0)
                push(capsule(P(sole - fd * 45), P(sole + fd * 95), 1.4, 1.4), pal.red, D(l.ankle) - 0.4)
            }
            if spec.flags.contains("poles") {
                for side in ["L", "R"] {
                    let g = implementPoint(s, side)
                    let dir = normed(V3(0, -1, 0) + s.root.apply(V3(-1, 0, 0)) * 0.35)
                    push(capsule(P(g - dir * 6), P(g + dir * 104), 0.9, 0.7), pal.steel, D(g) + 0.6)
                }
            }
        case "bowlingballs":
            // A bowling ball hanging in each hand.
            for side in ["L", "R"] {
                let c = implementPoint(s, side) + V3(0, -9, 0)
                push(sphere(c, 10.8), "#1E1E22", D(c) + 0.5)
            }
        case "bow2":
            // Recurve bow in the left hand: limbs curve back from the grip, the string runs to the draw hand.
            let g = implementPoint(s, "L"), hand = implementPoint(s, "R")
            let up = normed(s.chest.apply(V3(0, 1, 0)))
            let toBack = normed(hand - g)
            let tipU = g + up * 64 + toBack * 10, tipD = g - up * 64 + toBack * 10
            let midU = g + up * 34 - toBack * 3, midD = g - up * 34 - toBack * 3
            for (a, b) in [(g, midU), (midU, tipU), (g, midD), (midD, tipD)] { push(capsule(P(a), P(b), 1.4, 1.1), pal.plate, D(g) + 0.9) }
            // The string follows the draw hand while it's on it; an arrow shows once drawn.
            let reachLen = (hand - g).length
            let onString = reachLen < 86, drawn = onString && reachLen > 34
            let string = onString ? hand : g + toBack * 12
            push(capsule(P(tipU), P(string), 0.35, 0.35), pal.steel, D(g) + 0.3)
            push(capsule(P(string), P(tipD), 0.35, 0.35), pal.steel, D(g) + 0.3)
            if drawn { push(capsule(P(hand - normed(g - hand) * 4), P(g + normed(g - hand) * 6), 0.5, 0.5), pal.red, D(g) + 0.35) }
        case "rifle2":
            // Target rifle (or a training dowel): butt in the right shoulder pocket, fore-end on the left hand.
            let butt = s.R.shoulder + s.chest.apply(V3(1, 0, 0)) * 4 - s.chest.apply(V3(0, 1, 0)) * 2
            let rest = implementPoint(s, "L")
            let dir = normed(rest - butt)
            let dowel = spec.flags.contains("dowel")
            let muzzle = rest + dir * (dowel ? 50 : 60)
            if dowel {
                push(capsule(P(butt), P(muzzle), 1.2, 1.2), pal.wood, D(rest) + 0.9)
            } else {
                push(capsule(P(butt), P(butt + dir * 34), 3.6, 2.4), pal.wood, D(rest) + 0.9)
                push(capsule(P(butt + dir * 30), P(muzzle), 1.6, 1.3), pal.plate, D(rest) + 0.91)
            }
        case "flag":
            // Color-guard flag: the pole runs from the bottom hand (L) through the top hand (R), the silk near its top.
            let lo = implementPoint(s, "L"), hi = implementPoint(s, "R")
            let dir = normed(hi - lo)
            let top = lo + dir * 150
            out += segmented(lo - dir * 24, top, 1.1, 1.1, Color(hex: pal.steel), n: 12)
            let across = normed(fwFlat - dir * fwFlat.dot(dir))
            out.append(RigShape(points: hull([P(top), P(top - dir * 56), P(top - dir * 56 + across * 44), P(top + across * 44)]),
                                color: Color(hex: pal.red), opacity: 0.9, depth: D(top) + 0.5))
        case "horn":
            // A brass instrument held up at the mouth, bell forward.
            let hf = s.headFrame.apply(V3(1, 0, 0)), hu = s.headFrame.apply(V3(0, 1, 0))
            let mouth = s.head + hf * 9 - hu * 3
            let bell = mouth + hf * 42
            push(capsule(P(mouth), P(bell), 1.4, 2.4), "#C9A227", D(mouth) + 1)
            push(hull(disc(bell, hf, 7, 16)), "#C9A227", D(bell) + 1.01)
        case "towels":
            // A towel (or gi fabric) in each hand, hanging from the bar above.
            for side in ["L", "R"] {
                let g = implementPoint(s, side)
                push(capsule(P(g + V3(0, -4, 0)), P(g + V3(0, 24, 0)), 2.6, 2.6), "#E8E6DF", D(g) + 0.7)
            }
        case "map":
            // A folded map held up in the left hand to read.
            let g = implementPoint(s, "L")
            let fw = normed(s.chest.apply(V3(1, 0, 0))), up = normed(s.chest.apply(V3(0, 1, 0))), lat = normed(s.chest.apply(V3(0, 0, 1)))
            let c = g + up * 5 - lat * 5
            push(hull([(-7.0, -9.0), (7, -9), (7, 9), (-7, 9)].map { P(c + lat * $0.0 + up * $0.1) }), "#F2EFE6", D(c + fw * 2) + 0.6)
            push(hull([(-5.0, 2.0), (4, 6), (4, 7.5), (-5, 3.5)].map { P(c + lat * $0.0 + up * ($0.1 - 4)) }), pal.red, D(c + fw * 2) + 0.61)
        case "kickboard":
            let c = implementPoint(s, "hands") + fwFlat * 12
            let lat3 = normed(s.root.apply(V3(0, 0, 1)))
            push(hull([(-12.0, -14.0), (14, -14), (14, 14), (-12, 14)].map { P(c + fwFlat * $0.0 + lat3 * $0.1) }), pal.red, D(c) + 0.5)
        case "pad":
            // A tackle / ruck pad held upright in front of the chest.
            let c = implementPoint(s, "hands") + fwFlat * 7
            let lat3 = normed(s.root.apply(V3(0, 0, 1)))
            push(hull([(-16.0, -24.0), (16, -24), (16, 22), (-16, 22)].map { P(c + lat3 * $0.0 + V3(0, $0.1, 0)) }), pal.red, D(c) + 0.5)
        case "jumprope":
            let a = implementPoint(s, "L"), b = implementPoint(s, "R")
            let low = min(s.L.toe.y, s.R.toe.y) - 1
            var pts: [V3] = []
            for i in 0...16 {
                let t = Double(i) / 16
                let lat = a * (1 - t) + b * t
                let sag = sin(t * .pi)
                pts.append(V3(lat.x, lat.y + (low - lat.y) * sag, lat.z) + fwFlat * (6 * sag))
            }
            for i in 0..<(pts.count - 1) { push(capsule(P(pts[i]), P(pts[i + 1]), 0.6, 0.6), pal.red, (D(pts[i]) + D(pts[i + 1])) / 2) }
        case "wristroller":
            let a = implementPoint(s, "L"), b = implementPoint(s, "R")
            out += segmented(a + (a - b) * 0.2, b + (b - a) * 0.2, 1.5, 1.5, Color(hex: pal.steel), n: 6)
            let mid = (a + b) / 2, low = mid + V3(0, -(spec.numbers["drop"] ?? 30), 0)
            push(capsule(P(mid), P(low), 0.5, 0.5), pal.steel, D(mid) + 0.4)
            push(hull(disc(low, V3(1, 0, 0), 6, 12)), pal.plate, D(mid) + 0.41)
        case "rope":
            var pts: [V3] = []
            for i in 0...10 {
                pts.append(at + fwFlat * (Double(i) * 8) + V3(0, -at.y * (Double(i) / 10) * 0.9 + sin(Double(i) * 1.3 + (spec.numbers["phase"] ?? 0)) * 4, 0))
            }
            for i in 0..<(pts.count - 1) { push(capsule(P(pts[i]), P(pts[i + 1]), 1.3, 1.3), pal.red, (D(pts[i]) + D(pts[i + 1])) / 2) }
        default:
            break
        }
        return out
    }

    // MARK: Fixtures

    static func fixtureShapes(_ s: RigSkeleton, _ fx: RigPlayback.Fixture, _ pal: RigPalette) -> [RigShape] {
        var out: [RigShape] = []
        func push(_ points: [CGPoint], _ hex: String, _ depth: Double, opacity: Double = 1, stroke: Double? = nil) {
            out.append(RigShape(points: points, color: Color(hex: hex), opacity: opacity, depth: depth, stroke: stroke))
        }
        let ax = M3.rotY(fx.view).apply(V3(1, 0, 0)), az = M3.rotY(fx.view).apply(V3(0, 0, 1))
        let o = fx.origin
        // A bike pitches about its rear-wheel contact and lifts; on a path the
        // whole fixture travels (turned and moved) with the athlete.
        let pitch = s.fxPitch * .pi / 180, lift = s.fxLift, shift = s.fxShift
        let pivot = fx.kind == "bike" ? (fx.points["crank"]?.x ?? o.x) - 38 : o.x
        let move = s.fxMove
        func W(_ x: Double, _ y: Double, _ z: Double? = nil) -> V3 {
            var bx = x, by = y
            if pitch != 0 {
                let dx = x - pivot
                bx = pivot + dx * cos(pitch) - y * sin(pitch)
                by = dx * sin(pitch) + y * cos(pitch)
            }
            let q = V3(o.x, 0, o.z) + ax * (bx + shift - o.x) + V3(0, by + lift, 0) + az * ((z ?? o.z) - o.z)
            guard let move else { return q }
            return M3.rotY(move.heading).apply(q) + move.offset
        }
        func W(_ p: V3) -> V3 { W(p.x, p.y, p.z) }
        func box(_ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ z0: Double, _ z1: Double, _ hex: String, _ dz: Double = 0) {
            var pts: [CGPoint] = []
            for x in [x0, x1] { for y in [y0, y1] { for z in [z0, z1] { pts.append(P(W(x, y, z))) } } }
            push(hull(pts), hex, D(W((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)) + dz)
        }
        let n = fx.numbers, p = fx.points
        switch fx.kind {
        case "bench":
            let x0 = n["x0"] ?? 0, x1 = n["x1"] ?? 0, top = n["top"] ?? 34, z = n["z"] ?? 0
            box(x0, x1, top - 5, top, z - 12, z + 12, pal.pad, -30)
            for x in [x0 + 6, x1 - 6] { box(x - 2, x + 2, 0, top - 5, z - 9, z + 9, pal.steel, -31) }
        case "box":
            let z = n["z"] ?? 0
            // `foam`: a soft balance pad instead of a wooden box.
            box(n["x0"] ?? 0, n["x1"] ?? 0, 0, n["top"] ?? 34, z - 20, z + 20, (n["foam"] ?? 0) != 0 ? pal.pad : pal.wood, -40)
        case "wall":
            let x = n["x"] ?? 0
            if n["side"] != nil {
                let z = n["z"] ?? 0
                box(x - 160, x + 160, 0, 150, z - 3, z + 3, pal.ground, -60)
            } else {
                box(x, x + 6, 0, 150, -40, 40, pal.ground, -60)
            }
        case "bar":
            let at = W(p["at"] ?? .zero)
            out += segmented(at + az * 45, at - az * 45, 1.6, 1.6, Color(hex: pal.steel), n: 14)
            for σ in [1.0, -1.0] {
                let foot = V3(at.x, 0, at.z) + az * (σ * 45)
                push(capsule(P(foot), P(at + az * (σ * 45)), 1.4, 1.4), pal.steel, -60)
            }
        case "water":
            // The pool: water behind the swimmer, a clear layer over whatever is
            // under the surface, and the surface line. Wide enough for any
            // framing; left out of the camera framing itself (isBall).
            let level = n["level"] ?? 0
            let sheet = [CGPoint(x: -4000, y: -level), CGPoint(x: 4000, y: -level), CGPoint(x: 4000, y: -level + 600), CGPoint(x: -4000, y: -level + 600)]
            push(sheet, pal.water, -1e5, opacity: 0.35)
            out.append(RigShape(points: sheet, color: Color(hex: pal.water), opacity: 0.3, depth: 1e5, isBall: true))
            let line = [CGPoint(x: -4000, y: -level - 0.6), CGPoint(x: 4000, y: -level - 0.6), CGPoint(x: 4000, y: -level + 0.6), CGPoint(x: -4000, y: -level + 0.6)]
            out.append(RigShape(points: line, color: Color(hex: pal.water), opacity: 0.9, depth: 1e5 + 1, isBall: true))
            // The pool deck at the edge, to climb out onto.
            if let deckX = n["deckX"], let top = n["deckTop"] {
                out.append(RigShape(points: [CGPoint(x: deckX, y: -top), CGPoint(x: 4000, y: -top), CGPoint(x: 4000, y: 600), CGPoint(x: deckX, y: 600)],
                                    color: Color(hex: pal.ground), depth: 1e5 + 2, isBall: true))
            }
        case "bike":
            let crankB = p["crank"] ?? .zero
            let crank = W(crankB), seat = W(p["seat"] ?? .zero), bars = W(p["bars"] ?? .zero)
            func wheelAt(_ dx: Double) -> V3 { W(crankB.x + dx, 22, crankB.z) }
            for c in [wheelAt(-38), wheelAt(40)] { push(hull(disc(c, az, 22, 24)), pal.steel, -50, stroke: 2) }
            push(capsule(P(crank), P(seat), 1.3, 1.3), pal.steel, -40)
            push(capsule(P(seat), P(bars), 1.3, 1.3), pal.steel, -40)
            push(capsule(P(crank), P(wheelAt(40)), 1.3, 1.3), pal.steel, -40)
            push(hull(disc(crank, az, n["r"] ?? 17, 16)), pal.steel, -39, stroke: 1)
        case "rower":
            let rail0 = n["rail0"] ?? 0, rail1 = n["rail1"] ?? 0, seatTop = n["seatTop"] ?? 30
            let foot = p["foot"] ?? .zero, fly = p["fly"] ?? .zero
            let oz = o.z
            box(rail0, rail1, seatTop - 8, seatTop - 4, oz - 5, oz + 5, pal.steel, -45)
            for x in [rail0 + 3, rail1 - 3] { box(x - 1.5, x + 1.5, 0, seatTop - 8, oz - 5, oz + 5, pal.steel, -46) }
            let seatX = o.x + (s.pelvis - o).dot(ax)
            box(seatX - 8, seatX + 8, seatTop - 4, seatTop, oz - 9, oz + 9, pal.pad, -20)
            push(hull(disc(W(fly.x, fly.y, oz), az, 16, 20)), pal.plate, -44)
            box(foot.x - 2, foot.x + 2, foot.y - 4, foot.y + 14, oz - 12, oz + 12, pal.steel, -30)
        case "incline":
            let seatX = n["seatX"] ?? 0, seatTop = n["seatTop"] ?? 30
            let from = p["padFrom"] ?? .zero, to = p["padTo"] ?? .zero
            box(seatX - 14, seatX + 12, seatTop - 5, seatTop, o.z - 12, o.z + 12, pal.pad, -30)
            push(capsule(P(W(from.x, from.y, o.z)), P(W(to.x, to.y, o.z)), 5, 5), pal.pad, D(W(from.x, from.y, o.z - 12)) - 30)
            box(seatX - 2, seatX + 2, 0, seatTop - 5, o.z - 9, o.z + 9, pal.steel, -31)
        case "mat":
            box(n["x0"] ?? 0, n["x1"] ?? 0, 0, 1.5, -25, 25, pal.ground, -1e5 + 1)
        case "net":
            let x = n["x"] ?? 30, top = n["top"] ?? 150
            box(x - 0.6, x + 0.6, top - 40, top, -60, 60, pal.ground, 0)
            box(x - 1.2, x + 1.2, 0, top, -61, -59, pal.steel, -60)
        case "wheelchair":
            let seat = p["seat"] ?? .zero
            let c = V3(seat.x - 2, 26, seat.z)
            push(hull(disc(W(c.x, c.y, o.z - 13), az, 26, 24)), pal.steel, -40, stroke: 2.4)
            push(hull(disc(W(c.x, c.y, o.z + 13), az, 26, 24)), pal.steel, 40, stroke: 2.4)
            box(seat.x - 14, seat.x + 10, seat.y - 4, seat.y, o.z - 12, o.z + 12, pal.pad, -1)
        case "blocks":
            // Starting blocks: a pedal behind each foot on a rail.
            let l = p["L"] ?? .zero, r = p["R"] ?? .zero
            for q in [l, r] { box(q.x - 10, q.x - 2, 0, 9, q.z - 5, q.z + 5, pal.plate, -2) }
            box(min(l.x, r.x) - 16, max(l.x, r.x), 0, 2, o.z - 2, o.z + 2, pal.steel, -3)
        case "racingchair":
            // Big cambered wheels with push rims, a low kneeling seat, a long frame to a small front wheel.
            let seat = p["seat"] ?? .zero
            let c = V3(seat.x + 2, 33, 0)
            for sd in [-1.0, 1.0] {
                push(hull(disc(W(c.x, c.y, o.z + sd * 19), az, 33, 28)), pal.steel, sd * 40, stroke: 2.2)
                push(hull(disc(W(c.x, c.y, o.z + sd * 21), az, 24, 24)), pal.plate, sd * 41, stroke: 1.6)
            }
            box(seat.x - 16, seat.x + 16, seat.y - 8, seat.y, o.z - 12, o.z + 12, pal.pad, -1)
            let front = V3(seat.x + 120, 9, 0)
            push(capsule(P(W(seat.x + 10, seat.y - 4)), P(W(front.x, front.y + 4)), 1.6, 1.4), pal.steel, D(W(seat.x + 60, 20)) - 1)
            push(hull(disc(W(front.x, front.y), az, 9, 18)), pal.steel, D(W(front.x, front.y)), stroke: 1.8)
        case "sled":
            let x = n["x"] ?? 50
            box(x, x + 30, 0, 8, -16, 16, pal.steel, -5)
            box(x + 8, x + 12, 8, 40, -14, -10, pal.steel, -8)
            box(x + 8, x + 12, 8, 40, 10, 14, pal.steel, 8)
        case "roller":
            let at = W(p["at"] ?? .zero)
            push(hull(disc(at + az * 15, az, 7, 16) + disc(at - az * 15, az, 7, 16)), pal.red, D(at) - 2)
        case "kickball":
            let c = W(p["ball"] ?? .zero)
            push(circle(P(c), 5.8, 20), pal.red, D(c) + 0.2)
        case "ball":
            let at = W(p["at"] ?? .zero)
            push(circle(P(at), n["r"] ?? 30, 28), pal.red, D(at) - 12, opacity: 0.9)
        case "surfboard":
            // A surfboard lying under the athlete (on a mat or the water).
            let x0 = n["x0"] ?? -110, x1 = n["x1"] ?? 90, y = n["y"] ?? 0
            if (n["water"] ?? 0) > 0 {
                let sheet = [CGPoint(x: -4000, y: -(y + 1)), CGPoint(x: 4000, y: -(y + 1)), CGPoint(x: 4000, y: -(y + 1) + 600), CGPoint(x: -4000, y: -(y + 1) + 600)]
                push(sheet, pal.water, -1e5, opacity: 0.35)
                out.append(RigShape(points: sheet, color: Color(hex: pal.water), opacity: 0.3, depth: 1e5, isBall: true))
            }
            var pts: [CGPoint] = []
            for i in 0...12 {
                let t = Double(i) / 12, x = x0 + (x1 - x0) * t, w = 26 * sin(.pi * min(1, t * 1.15)) + 2
                pts.append(P(W(x, y + 3, o.z + w))); pts.append(P(W(x, y, o.z - w)))
            }
            push(hull(pts), "#F2B134", -4)
            push(hull([P(W(x0 + 10, y + 3.2, o.z + 1)), P(W(x1 - 10, y + 3.2, o.z + 1)), P(W(x1 - 10, y + 3.2, o.z - 1)), P(W(x0 + 10, y + 3.2, o.z - 1))]), pal.red, -3.9)
        case "horse":
            // A horse under the rider: barrel, neck and head forward, four legs, a tail.
            let seat = p["seat"] ?? .zero
            let x = seat.x, top = seat.y - 6
            let coat = "#8B5A3C"
            push(hull((0..<20).map { i -> CGPoint in let a = Double(i) / 20 * .pi * 2; return P(W(x + 6 + cos(a) * 74, top - 30 + sin(a) * 30, o.z)) }), coat, -30)
            push(hull([P(W(x + 48, top - 20, o.z)), P(W(x + 70, top - 40, o.z)), P(W(x + 104, top + 26, o.z)), P(W(x + 88, top + 36, o.z))]), coat, -30)
            push(hull([P(W(x + 88, top + 38, o.z)), P(W(x + 104, top + 28, o.z)), P(W(x + 136, top + 4, o.z)), P(W(x + 130, top - 6, o.z))]), coat, -29.9)
            for (dx, dz) in [(48.0, 10.0), (48, -10), (-46, 10), (-46, -10)] {
                push(capsule(P(W(x + dx, top - 50, o.z + dz)), P(W(x + dx + 2, 2, o.z + dz)), 5.5, 3.2), dz > 0 ? coat : "#6E4730", dz > 0 ? 30 : -35)
            }
            push(capsule(P(W(x - 64, top - 20, o.z)), P(W(x - 76, top - 70, o.z)), 3, 2), "#3A2A20", -31)
            box(x - 14, x + 14, top - 4, top + 2, o.z - 12, o.z + 12, pal.plate, -1)
        case "climbwall":
            // A climbing wall in front with coloured holds.
            let x = n["x"] ?? 30
            box(x, x + 6, 0, 320, o.z - 160, o.z + 160, pal.ground, -60)
            let colours = ["#E5383B", "#2F6FE0", "#D8E83A", "#F28C28", "#2BB673"]
            var k = 0
            for hy in stride(from: 20.0, to: 300, by: 34) {
                for hz in stride(from: -140.0, through: 140, by: 40) {
                    let c = W(x - 1, hy + (hz / 40).truncatingRemainder(dividingBy: 2) * 10, o.z + hz + (hy / 34).truncatingRemainder(dividingBy: 2) * 16)
                    push(circle(P(c), 3.2, 8), colours[k % colours.count], -59)
                    k += 1
                }
            }
        case "boat":
            // A rowing shell on the water: hull along the boat, a rigger out to the oar's pin.
            let level = n["level"] ?? 0
            let sheet = [CGPoint(x: -4000, y: -level), CGPoint(x: 4000, y: -level), CGPoint(x: 4000, y: -level + 600), CGPoint(x: -4000, y: -level + 600)]
            push(sheet, pal.water, -1e5, opacity: 0.35)
            push(hull([P(W(o.x - 170, level + 2)), P(W(o.x + 170, level + 2)), P(W(o.x + 130, level - 8)), P(W(o.x - 130, level - 8))]), "#F4F4F2", -20)
            push(capsule(P(W(o.x + 8, level + 10)), P(W(o.x + 8, level + 22, o.z - 70)), 1, 1), pal.steel, -21)
            out.append(RigShape(points: sheet, color: Color(hex: pal.water), opacity: 0.25, depth: 1e5, isBall: true))
        case "ramp":
            // A boccia ramp: a sloped chute from beside the chair down to the floor ahead.
            let x0 = n["x0"] ?? 20, x1 = n["x1"] ?? 110, top = n["top"] ?? 60
            // …with the athlete's wheelchair behind it.
            let seat = p["seat"] ?? .zero
            let wc = V3(seat.x - 2, 26, seat.z)
            push(hull(disc(W(wc.x, wc.y, o.z - 13), az, 26, 24)), pal.steel, -40, stroke: 2.4)
            push(hull(disc(W(wc.x, wc.y, o.z + 13), az, 26, 24)), pal.steel, 40, stroke: 2.4)
            box(seat.x - 14, seat.x + 10, seat.y - 4, seat.y, o.z - 12, o.z + 12, pal.pad, -1)
            push(hull([P(W(x0, top, o.z - 7)), P(W(x0, top, o.z + 7)), P(W(x1, 1, o.z + 7)), P(W(x1, 1, o.z - 7))]), pal.wood, -8)
            box(x0 - 2, x0 + 2, 0, top, o.z - 5, o.z + 5, pal.steel, -9)
        case "control":
            // An orienteering control: a post with the orange-and-white flag.
            let x = n["x"] ?? 30
            box(x - 1, x + 1, 0, 70, -1, 1, pal.steel, -2)
            push(hull([P(W(x - 7, 84)), P(W(x + 7, 84)), P(W(x + 7, 70))]), "#E8762B", D(W(x, 77)))
            push(hull([P(W(x - 7, 84)), P(W(x - 7, 70)), P(W(x + 7, 70))]), "#F4F4F2", D(W(x, 77)) + 0.01)
        case "stairs":
            let x = n["x"] ?? 0, run = n["run"] ?? 30, rise = n["rise"] ?? 17, count = Int(n["count"] ?? 6)
            for i in 0..<count {
                box(x + Double(i) * run, x + Double(count) * run + 30, 0, Double(i + 1) * rise, -30, 30, pal.pad, -40 - Double(i) * 0.01)
            }
        case "hurdle", "cone", "ladder":
            let x = n["x"] ?? 30
            if fx.kind == "cone" {
                push([P(V3(x - 5, 0, 0)), P(V3(x + 5, 0, 0)), P(V3(x, 14, 0))], pal.red, -20)
            } else if fx.kind == "hurdle" {
                let h = n["height"] ?? 26
                for i in 0..<Int(n["count"] ?? 1) {
                    let hx = x + Double(i) * (n["gap"] ?? 0)
                    box(hx - 1, hx + 1, 0, h, -20, -18, pal.steel, -30)
                    box(hx - 1, hx + 1, 0, h, 18, 20, pal.steel, 30)
                    box(hx - 1.5, hx + 1.5, h - 3, h + 1, -20, 20, pal.red, 0)
                }
            } else {
                for i in 0..<4 { box(x + Double(i) * 18, x + Double(i) * 18 + 1.5, 0, 0.8, -18, 18, pal.red, -1e5 + 2) }
            }
        default:
            break
        }
        return out
    }
}
