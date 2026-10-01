import SwiftUI

/// The sport in the air, not in a photo: thin abstract geometry — a golf
/// swing arc, court arcs, lane lines, water, pitch lines — at a few percent
/// opacity behind the main screens. Atmosphere, not decoration.
struct SportAtmosphere: View {
    let sportSlug: String

    enum Motif {
        case swing, court, lanes, water, pitch, net, orbit
    }

    static func motif(for slug: String) -> Motif {
        let s = slug.lowercased()
        if s.contains("golf") { return .swing }
        if s.contains("basketball") || s.contains("netball") { return .court }
        if s.contains("track") || s.contains("running") || s.contains("cross-country") || s.contains("athletics")
            || s.contains("sprint") || s.contains("hurdles") { return .lanes }
        if s.contains("swim") || s.contains("diving") || s.contains("water-polo") || s.contains("rowing")
            || s.contains("surf") { return .water }
        if s.contains("soccer") || s.contains("football") || s.contains("hockey") || s.contains("lacrosse")
            || s.contains("rugby") || s.contains("ultimate") { return .pitch }
        if s.contains("tennis") || s.contains("badminton") || s.contains("volleyball") || s.contains("pickleball")
            || s.contains("squash") { return .net }
        return .orbit
    }

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let line = GraphicsContext.Shading.color(.white.opacity(0.05))
            let red = GraphicsContext.Shading.color(AppTheme.brand.opacity(0.08))
            let w = size.width, h = size.height
            var path = Path()
            switch Self.motif(for: sportSlug) {
            case .swing:
                // Swing arcs around the golfer's axis and a ball flight.
                for i in 0..<4 {
                    let r = w * (0.55 + CGFloat(i) * 0.14)
                    path.addArc(center: CGPoint(x: w * 0.5, y: h * 0.62), radius: r,
                                startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                }
                context.stroke(path, with: line, lineWidth: 1)
                var flight = Path()
                flight.move(to: CGPoint(x: w * 0.1, y: h * 0.7))
                flight.addQuadCurve(to: CGPoint(x: w * 1.05, y: h * 0.3), control: CGPoint(x: w * 0.55, y: h * 0.05))
                context.stroke(flight, with: red, style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
            case .court:
                path.addArc(center: CGPoint(x: w * 0.5, y: -h * 0.02), radius: w * 0.62,
                            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                path.addArc(center: CGPoint(x: w * 0.5, y: -h * 0.02), radius: w * 0.22,
                            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                path.addEllipse(in: CGRect(x: w * 0.5 - 12, y: h * 0.04, width: 24, height: 10))
                context.stroke(path, with: line, lineWidth: 1)
                var shot = Path()
                shot.move(to: CGPoint(x: w * 0.15, y: h * 0.62))
                shot.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.06), control: CGPoint(x: w * 0.25, y: -h * 0.05))
                context.stroke(shot, with: red, style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
            case .lanes:
                for i in 0..<7 {
                    let x = w * (-0.1 + CGFloat(i) * 0.2)
                    path.move(to: CGPoint(x: x, y: h))
                    path.addLine(to: CGPoint(x: x + w * 0.35, y: 0))
                }
                context.stroke(path, with: line, lineWidth: 1)
                var streaks = Path()
                for i in 0..<5 {
                    let y = h * (0.2 + CGFloat(i) * 0.09)
                    streaks.move(to: CGPoint(x: w * 0.55, y: y))
                    streaks.addLine(to: CGPoint(x: w * 0.95, y: y - 6))
                }
                context.stroke(streaks, with: red, lineWidth: 1)
            case .water:
                for i in 0..<6 {
                    let y = h * (0.12 + CGFloat(i) * 0.13)
                    path.move(to: CGPoint(x: 0, y: y))
                    for x in stride(from: 0, through: w, by: w / 8) {
                        let wave = sin((x / w) * .pi * 3 + CGFloat(i)) * 10
                        path.addLine(to: CGPoint(x: x, y: y + wave))
                    }
                }
                context.stroke(path, with: line, lineWidth: 1)
            case .pitch:
                path.addEllipse(in: CGRect(x: w * 0.5 - w * 0.22, y: h * 0.32, width: w * 0.44, height: w * 0.44))
                path.move(to: CGPoint(x: 0, y: h * 0.32 + w * 0.22))
                path.addLine(to: CGPoint(x: w, y: h * 0.32 + w * 0.22))
                path.addRect(CGRect(x: w * 0.22, y: -2, width: w * 0.56, height: h * 0.12))
                context.stroke(path, with: line, lineWidth: 1)
                var run = Path()
                run.move(to: CGPoint(x: w * 0.1, y: h * 0.85))
                run.addCurve(to: CGPoint(x: w * 0.9, y: h * 0.2), control1: CGPoint(x: w * 0.6, y: h * 0.9),
                             control2: CGPoint(x: w * 0.3, y: h * 0.3))
                context.stroke(run, with: red, style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
            case .net:
                path.addRect(CGRect(x: w * 0.12, y: h * 0.05, width: w * 0.76, height: h * 0.9))
                path.move(to: CGPoint(x: w * 0.12, y: h * 0.5))
                path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.5))
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.05))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.95))
                context.stroke(path, with: line, lineWidth: 1)
            case .orbit:
                for i in 0..<4 {
                    let r = w * (0.3 + CGFloat(i) * 0.18)
                    path.addEllipse(in: CGRect(x: w * 0.5 - r, y: h * 0.18 - r * 0.6, width: r * 2, height: r * 1.2))
                }
                context.stroke(path, with: line, lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
