import SwiftUI

struct OverlayIconView: View {
    let type: ReminderType
    let onDismiss: () -> Void

    private let circleSize: CGFloat = 120

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: 0.95, saturation: 0.55, brightness: 1.0),
                Color(hue: 0.06, saturation: 0.65, brightness: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: circleSize, height: circleSize)

            Circle()
                .strokeBorder(Color(white: 0.15), lineWidth: 4)
                .frame(width: circleSize, height: circleSize)

            switch type {
            case .posture:
                PostureIcon()
            case .blink:
                BlinkIcon()
            case .eyeBreak:
                Image(systemName: "binoculars")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color(white: 0.15))
            }
        }
        .frame(width: 200, height: 200)
        .contentShape(Circle())
        .onTapGesture { onDismiss() }
    }
}

// MARK: - Posture: person on chair, slouched -> upright
// Reference: side-view stick figure on a simple chair, facing left.
// Slouched: head forward/down, back curved in a C-shape.
// Upright: head up, back straight and vertical.

private struct PostureIcon: View {
    @State private var showUpright = false

    var body: some View {
        ZStack {
            // Slouched frame
            PostureFigure(progress: 0)
                .fill(Color(white: 0.15))
                .opacity(showUpright ? 0 : 1)

            // Upright frame
            PostureFigure(progress: 1)
                .fill(Color(white: 0.15))
                .opacity(showUpright ? 1 : 0)
        }
        .frame(width: 75, height: 75)
        .onAppear {
            // Show slouched for 1.5s, then swap to upright
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showUpright = true
                }
            }
        }
    }
}

private struct PostureFigure: Shape, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (b - a) * progress
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let chairLw: CGFloat = 0.04 * w

        // ── CHAIR (constant, simple side-view, facing left) ──

        // Seat
        stroke(&p, from: (0.18, 0.62), to: (0.68, 0.62), lw: chairLw, w: w, h: h)
        // Backrest
        stroke(&p, from: (0.68, 0.62), to: (0.68, 0.28), lw: chairLw, w: w, h: h)
        // Front leg (angled forward)
        stroke(&p, from: (0.20, 0.62), to: (0.16, 0.90), lw: chairLw, w: w, h: h)
        // Back leg (angled back)
        stroke(&p, from: (0.66, 0.62), to: (0.70, 0.90), lw: chairLw, w: w, h: h)

        // ── PERSON (facing left) ──

        let bodyLw: CGFloat = 0.07 * w
        let armLw: CGFloat = 0.05 * w
        let legLw: CGFloat = 0.065 * w

        // Hip on the seat (constant)
        let hipX: CGFloat = 0.52 * w
        let hipY: CGFloat = 0.58 * h

        // Head
        // Slouched: far forward and LOW (near seat level)
        // Upright: centered above hip, high up
        let headR: CGFloat = 0.09 * w
        let headX = lerp(0.18, 0.52) * w
        let headY = lerp(0.44, 0.06) * h
        p.addEllipse(in: CGRect(
            x: headX - headR, y: headY - headR,
            width: headR * 2, height: headR * 2
        ))

        // Spine: neck to hip
        // The neck connects just below the head
        let neckX = lerp(0.22, 0.52) * w
        let neckY = headY + headR

        // Slouched: back humps UP dramatically (control point high)
        // creating that rounded C-shape from the reference
        // Upright: nearly straight vertical line
        let spineCtrl1X = lerp(0.34, 0.51) * w
        let spineCtrl1Y = lerp(0.12, 0.30) * h
        let spineCtrl2X = lerp(0.52, 0.52) * w
        let spineCtrl2Y = lerp(0.35, 0.45) * h

        var spine = Path()
        spine.move(to: CGPoint(x: neckX, y: neckY))
        spine.addCurve(
            to: CGPoint(x: hipX, y: hipY),
            control1: CGPoint(x: spineCtrl1X, y: spineCtrl1Y),
            control2: CGPoint(x: spineCtrl2X, y: spineCtrl2Y)
        )
        p.addPath(spine.strokedPath(StrokeStyle(lineWidth: bodyLw, lineCap: .round)))

        // Arms: hang from the spine curve, resting near knees
        // Slouched: arms hang straight down between the knees
        // Upright: arms rest on lap
        let shoulderX = lerp(0.26, 0.48) * w
        let shoulderY = lerp(0.34, 0.24) * h
        let handX = lerp(0.20, 0.30) * w
        let handY = lerp(0.58, 0.52) * h
        let elbowX = lerp(0.18, 0.32) * w
        let elbowY = lerp(0.48, 0.40) * h

        var arm = Path()
        arm.move(to: CGPoint(x: shoulderX, y: shoulderY))
        arm.addQuadCurve(
            to: CGPoint(x: handX, y: handY),
            control: CGPoint(x: elbowX, y: elbowY)
        )
        p.addPath(arm.strokedPath(StrokeStyle(lineWidth: armLw, lineCap: .round)))

        // Upper leg: hip to knee
        let kneeX: CGFloat = 0.26 * w
        let kneeY: CGFloat = 0.65 * h

        stroke(&p, from: hipX, hipY, to: kneeX, kneeY, lw: legLw)

        // Lower leg: knee to foot
        let footX: CGFloat = 0.24 * w
        let footY: CGFloat = 0.90 * h

        stroke(&p, from: kneeX, kneeY, to: footX, footY, lw: legLw)

        return p
    }

    // Helpers for clean stroke lines
    private func stroke(_ p: inout Path, from: (CGFloat, CGFloat), to: (CGFloat, CGFloat), lw: CGFloat, w: CGFloat, h: CGFloat) {
        var line = Path()
        line.move(to: CGPoint(x: from.0 * w, y: from.1 * h))
        line.addLine(to: CGPoint(x: to.0 * w, y: to.1 * h))
        p.addPath(line.strokedPath(StrokeStyle(lineWidth: lw, lineCap: .round)))
    }

    private func stroke(_ p: inout Path, from fromX: CGFloat, _ fromY: CGFloat, to toX: CGFloat, _ toY: CGFloat, lw: CGFloat) {
        var line = Path()
        line.move(to: CGPoint(x: fromX, y: fromY))
        line.addLine(to: CGPoint(x: toX, y: toY))
        p.addPath(line.strokedPath(StrokeStyle(lineWidth: lw, lineCap: .round)))
    }
}

// MARK: - Blink: eye closes and opens

private struct BlinkIcon: View {
    @State private var blinkPhase: CGFloat = 1

    var body: some View {
        Image(systemName: "eye")
            .font(.system(size: 44, weight: .medium))
            .foregroundStyle(Color(white: 0.15))
            .scaleEffect(x: 1, y: blinkPhase)
            .onAppear {
                performBlinks()
            }
    }

    private func performBlinks() {
        withAnimation(.easeIn(duration: 0.12).delay(0.4)) {
            blinkPhase = 0.05
        }
        withAnimation(.easeOut(duration: 0.15).delay(0.52)) {
            blinkPhase = 1
        }
        withAnimation(.easeIn(duration: 0.12).delay(1.2)) {
            blinkPhase = 0.05
        }
        withAnimation(.easeOut(duration: 0.15).delay(1.32)) {
            blinkPhase = 1
        }
        withAnimation(.easeIn(duration: 0.12).delay(2.0)) {
            blinkPhase = 0.05
        }
        withAnimation(.easeOut(duration: 0.15).delay(2.12)) {
            blinkPhase = 1
        }
    }
}
