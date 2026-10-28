import SwiftUI

// ────────────────────────────────────────────────────────
// MARK: - INTERACTIVE LINE CHART
// ────────────────────────────────────────────────────────

struct InteractiveLineChart: View {
    let data: [Double]        // 0–1 normalised
    let rawValues: [Double]   // original values for display
    let color: Color
    let height: CGFloat
    @Binding var selectedIndex: Int?

    /// Parent passes selectedPeriod.rawValue — when it changes,
    /// the chart replays its entrance animation.
    var animationID: String = ""

    @State private var isScrubbing = false

    /// 0 → 1 draw progress.  The line trims left-to-right
    /// and the fill rises from the bottom simultaneously.
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let stepX = data.count > 1 ? w / CGFloat(data.count - 1) : w

            ZStack {
                // ── Fill gradient (rises from bottom) ──
                Path { path in
                    guard data.count > 1 else { return }
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, val) in data.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(val) * h * 0.85
                        if i == 0 { path.addLine(to: CGPoint(x: x, y: y)) }
                        else {
                            let prev = CGFloat(data[i-1]) * h * 0.85
                            let midX = (CGFloat(i-1) * stepX + x) / 2
                            path.addCurve(to: CGPoint(x: x, y: y),
                                          control1: CGPoint(x: midX, y: h - prev),
                                          control2: CGPoint(x: midX, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(colors: [color.opacity(0.25), color.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .scaleEffect(y: drawProgress, anchor: .bottom)
                .opacity(Double(drawProgress))

                // ── Line stroke (draws left → right) ──
                Path { path in
                    guard data.count > 1 else { return }
                    for (i, val) in data.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - CGFloat(val) * h * 0.85
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else {
                            let prev = CGFloat(data[i-1]) * h * 0.85
                            let midX = (CGFloat(i-1) * stepX + x) / 2
                            path.addCurve(to: CGPoint(x: x, y: y),
                                          control1: CGPoint(x: midX, y: h - prev),
                                          control2: CGPoint(x: midX, y: y))
                        }
                    }
                }
                .trim(from: 0, to: drawProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .shadow(color: color.opacity(0.4), radius: 6, y: 3)

                // ── Selected indicator ──
                if let idx = selectedIndex, idx < data.count, drawProgress >= 1.0 {
                    let x = CGFloat(idx) * stepX
                    let y = h - CGFloat(data[idx]) * h * 0.85

                    Rectangle()
                        .fill(color.opacity(0.4))
                        .frame(width: 1)
                        .position(x: x, y: h / 2)

                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                        .shadow(color: color.opacity(0.8), radius: 6)
                        .position(x: x, y: y)

                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .position(x: x, y: y)
                }

                // ── End dot ──
                if selectedIndex == nil, let last = data.last, drawProgress >= 1.0 {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .shadow(color: color.opacity(0.6), radius: 4)
                        .position(x: w, y: h - CGFloat(last) * h * 0.85)
                }
            }
            .drawingGroup()
            .contentShape(Rectangle().inset(by: -40))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard drawProgress >= 1.0 else { return }
                        let x = drag.location.x
                        let idx = Int(round(x / stepX))
                        let clamped = max(0, min(idx, data.count - 1))
                        if clamped != selectedIndex {
                            selectedIndex = clamped
                            if !isScrubbing {
                                isScrubbing = true
                                AuraHaptics.medium.impactOccurred()
                            } else {
                                AuraHaptics.throttledLight()
                            }
                        }
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        withAnimation(.easeOut(duration: 0.3)) { selectedIndex = nil }
                    }
            )
        }
        .frame(height: height)
        .onAppear { playEntrance() }
        .onChange(of: animationID) { _, _ in playEntrance() }
    }

    private func playEntrance() {
        // Cancel any in-flight animation by setting to 0 outside
        // an animation transaction, then start fresh.
        withAnimation(nil) { drawProgress = 0 }
        // Tiny delay ensures SwiftUI commits the reset frame
        // before the new animation begins — without this,
        // rapid taps (W→Y) can merge into one transaction.
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.5)) {
                drawProgress = 1
            }
        }
    }
}

// ────────────────────────────────────────────────────────
// MARK: - INTERACTIVE BAR CHART
// ────────────────────────────────────────────────────────

struct InteractiveBarChart: View {
    let data: [Double]        // 0–1 normalised
    let rawValues: [Double]   // original values for display
    let color: Color
    let height: CGFloat
    @Binding var selectedIndex: Int?

    /// Parent passes selectedPeriod.rawValue — when it changes,
    /// bars replay their grow-from-bottom entrance.
    var animationID: String = ""

    @State private var isScrubbing = false
    @State private var barGrowth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(data.count, 1)

            // One single stride for EVERYTHING: bars, dot, gesture.
            let stride = w / CGFloat(n)
            // Bar width: guarantee a minimum 1pt gap between bars so
            // they're always visually distinct — even in W with ~156 bars.
            // Y (4 bars) stays tight because stride is large.
            let maxBarW: CGFloat = 80
            let minGap: CGFloat = max(1.0, stride * 0.06)
            let barW = min(stride - minGap, maxBarW)
            let cornerR: CGFloat = 3

            ZStack {
                // ── Bars — absolute positioned via .position() ──
                ForEach(Array(data.enumerated()), id: \.offset) { i, val in
                    let targetH = max(CGFloat(val) * h * 0.85, 2) * barGrowth
                    let centerX = CGFloat(i) * stride + stride / 2
                    let centerY = h - targetH / 2

                    RoundedRectangle(cornerRadius: cornerR, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: selectedIndex == i
                                    ? [color, color.opacity(0.8)]
                                    : [color, color.opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: barW, height: targetH)
                        .position(x: centerX, y: centerY)
                        .opacity(selectedIndex != nil && selectedIndex != i ? 0.4 : 1.0)
                }

                // ── Selection dot — same stride = perfect alignment ──
                if let idx = selectedIndex, idx < n, barGrowth >= 1.0 {
                    let dotX = CGFloat(idx) * stride + stride / 2
                    let barTopY = h - CGFloat(data[idx]) * h * 0.85

                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .position(x: dotX, y: barTopY - 6)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .drawingGroup()
            .contentShape(Rectangle().inset(by: -40))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard barGrowth >= 1.0 else { return }
                        let idx = Int(drag.location.x / stride)
                        let clamped = max(0, min(idx, data.count - 1))
                        if clamped != selectedIndex {
                            selectedIndex = clamped
                            if !isScrubbing {
                                isScrubbing = true
                                AuraHaptics.medium.impactOccurred()
                            } else {
                                AuraHaptics.throttledLight()
                            }
                        }
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        withAnimation(.easeOut(duration: 0.3)) { selectedIndex = nil }
                    }
            )
        }
        .frame(height: height)
        .onAppear { playEntrance() }
        .onChange(of: animationID) { _, _ in playEntrance() }
    }

    private func playEntrance() {
        withAnimation(nil) { barGrowth = 0 }
        DispatchQueue.main.async {
            withAnimation(.spring(duration: 0.45, bounce: 0.12)) {
                barGrowth = 1
            }
        }
    }
}
