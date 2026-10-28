import SwiftUI

// ============================================================
// MARK: - SUN ARC SHAPE
// ============================================================

/// Full semicircular arc (sunrise → sunset).
struct SunArcShape: Shape {
    var inset: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let rx = rect.width / 2 - inset
        let ry = rect.height - 6
        p.move(to: CGPoint(x: cx - rx, y: rect.height - 2))
        let top = rect.height - ry - 2
        p.addCurve(
            to: CGPoint(x: cx + rx, y: rect.height - 2),
            control1: CGPoint(x: cx - rx * 0.2, y: top),
            control2: CGPoint(x: cx + rx * 0.2, y: top)
        )
        return p
    }
}

/// Partial arc from sunrise to `progress` (0→1) using De Casteljau split.
/// `progress` is `animatableData` so SwiftUI redraws every frame.
struct SunArcPartialShape: Shape {
    var progress: CGFloat
    var inset: CGFloat = 24

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0.001 else { return Path() }

        let pts = Self.bezierPoints(in: rect, inset: inset)
        let (left, _) = Self.deCasteljauSplit(p0: pts.0, p1: pts.1, p2: pts.2, p3: pts.3, t: progress)

        var p = Path()
        p.move(to: left.0)
        p.addCurve(to: left.3, control1: left.1, control2: left.2)
        return p
    }

    /// Bézier control points matching SunArcShape exactly.
    static func bezierPoints(in rect: CGRect, inset: CGFloat) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let cx = rect.midX
        let rx = rect.width / 2 - inset
        let ry = rect.height - 6
        let top = rect.height - ry - 2
        let p0 = CGPoint(x: cx - rx, y: rect.height - 2)
        let p1 = CGPoint(x: cx - rx * 0.2, y: top)
        let p2 = CGPoint(x: cx + rx * 0.2, y: top)
        let p3 = CGPoint(x: cx + rx, y: rect.height - 2)
        return (p0, p1, p2, p3)
    }

    /// De Casteljau split → (leftHalf 4 points, rightHalf 4 points)
    static func deCasteljauSplit(
        p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat
    ) -> ((CGPoint, CGPoint, CGPoint, CGPoint), (CGPoint, CGPoint, CGPoint, CGPoint)) {
        let mt = 1.0 - t
        let a0 = CGPoint(x: mt * p0.x + t * p1.x, y: mt * p0.y + t * p1.y)
        let a1 = CGPoint(x: mt * p1.x + t * p2.x, y: mt * p1.y + t * p2.y)
        let a2 = CGPoint(x: mt * p2.x + t * p3.x, y: mt * p2.y + t * p3.y)
        let b0 = CGPoint(x: mt * a0.x + t * a1.x, y: mt * a0.y + t * a1.y)
        let b1 = CGPoint(x: mt * a1.x + t * a2.x, y: mt * a1.y + t * a2.y)
        let pt = CGPoint(x: mt * b0.x + t * b1.x, y: mt * b0.y + t * b1.y)
        return ((p0, a0, b0, pt), (pt, b1, a2, p3))
    }
}

/// Draws the entire sun arc animation (curve + dot + glow + time)
/// from a single `animatableData` value, guaranteeing zero desync.
struct SunArcCanvas: View {
    var progress: CGFloat
    var timeLabel: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2.0)) { timeline in
            let phase = timeline.date.timeIntervalSince1970
                .truncatingRemainder(dividingBy: 2.0) / 2.0

            SunArcDrawing(progress: progress, timeLabel: timeLabel, pulsePhase: phase)
        }
    }
}

/// The actual animatable drawing. `progress` is `animatableData` so
/// SwiftUI interpolates it every frame — and the body computes BOTH
/// the curve path and the dot position from that SAME value atomically.
private struct SunArcDrawing: View, Animatable {
    var progress: CGFloat
    var timeLabel: String
    var pulsePhase: Double

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let inset: CGFloat = 24

            // ── Bézier points ──
            let rect = CGRect(x: 0, y: 0, width: w, height: h)
            let pts = SunArcPartialShape.bezierPoints(in: rect, inset: inset)
            let t = max(progress, 0.001)
            let (left, _) = SunArcPartialShape.deCasteljauSplit(
                p0: pts.0, p1: pts.1, p2: pts.2, p3: pts.3, t: t
            )
            let dotPt = left.3

            // ── Dot color: yellow → orange ──
            let dotColor = Color(
                red: 1.0,
                green: 0.90 - 0.45 * progress,
                blue: 0.20 - 0.10 * progress
            )

            // ── Partial curve path ──
            let curvePath = Path { p in
                p.move(to: left.0)
                p.addCurve(to: left.3, control1: left.1, control2: left.2)
            }

            // ── Full arc path (for backdrop) ──
            let fullPath = Path { p in
                p.move(to: pts.0)
                p.addCurve(to: pts.3, control1: pts.1, control2: pts.2)
            }

            ZStack {
                // Sky gradient backdrop
                fullPath
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 40))
                    .blur(radius: 12)

                // Golden curve
                curvePath
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.78, blue: 0.2),
                                Color(red: 1.0, green: 0.60, blue: 0.18)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )

                // Pulse ring
                Circle()
                    .stroke(dotColor.opacity(max(0.25 - 0.25 * pulsePhase, 0)), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .scaleEffect(1.0 + 0.6 * pulsePhase)
                    .position(x: dotPt.x, y: dotPt.y)

                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [dotColor.opacity(0.5), dotColor.opacity(0.06), Color.clear],
                            center: .center, startRadius: 1, endRadius: 16
                        )
                    )
                    .frame(width: 32, height: 32)
                    .position(x: dotPt.x, y: dotPt.y)

                // Dot
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.7), radius: 5)
                    .position(x: dotPt.x, y: dotPt.y)

                // Time label
                Text(timeLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(dotColor.opacity(0.8))
                    .position(x: dotPt.x, y: dotPt.y - 16)
            }
            .frame(width: w, height: h)
        }
    }
}
