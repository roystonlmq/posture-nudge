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
        let lw: CGFloat = 0.045 * w  // line width for chair

        // ──────────────────────────────
        // CHAIR (constant, simple side-view)
        // Person faces left, chair back is on the right
        // ──────────────────────────────

        // Seat - horizontal bar
        var seat = Path()
        seat.move(to: CGPoint(x: 0.20 * w, y: 0.64 * h))
        seat.addLine(to: CGPoint(x: 0.68 * w, y: 0.64 * h))
        p.addPath(seat.strokedPath(StrokeStyle(lineWidth: lw, lineCap: .round)))

        // Back rest - vertical bar on the right
        var back = Path()
        back.move(to: CGPoint(x: 0.68 * w, y: 0.64 * h))
        back.addLine(to: CGPoint(x: 0.68 * w, y: 0.30 * h))
        p.addPath(back.strokedPath(StrokeStyle(lineWidth: lw, lineCap: .round)))

        // Front left leg
        var frontLeg = Path()
        frontLeg.move(to: CGPoint(x: 0.22 * w, y: 0.64 * h))
        frontLeg.addLine(to: CGPoint(x: 0.18 * w, y: 0.88 * h))
        p.addPath(frontLeg.strokedPath(StrokeStyle(lineWidth: lw, lineCap: .round)))

        // Back right leg
        var backLeg = Path()
        backLeg.move(to: CGPoint(x: 0.66 * w, y: 0.64 * h))
        backLeg.addLine(to: CGPoint(x: 0.70 * w, y: 0.88 * h))
        p.addPath(backLeg.strokedPath(StrokeStyle(lineWidth: lw, lineCap: .round)))

        // ──────────────────────────────
        // PERSON (animated, facing left)
        // ──────────────────────────────

        let bodyLw: CGFloat = 0.07 * w

        // Hip - stays on the seat
        let hipX: CGFloat = 0.52 * w
        let hipY: CGFloat = 0.60 * h

        // Head
        let headR: CGFloat = 0.09 * w
        let headX = lerp(0.28, 0.52) * w
        let headY = lerp(0.26, 0.08) * h
        p.addEllipse(in: CGRect(
            x: headX - headR, y: headY - headR,
            width: headR * 2, height: headR * 2
        ))

        // Spine / back: from neck to hip
        // Slouched: neck is forward-left, spine curves like a C
        // Upright: neck is above hip, spine is nearly straight
        let neckX = lerp(0.32, 0.52) * w
        let neckY = headY + headR + 0.01 * h

        // Control point for the spine curve
        // Slouched: control point pulls the curve forward (left)
        // Upright: control point stays close to the straight line
        let spineCtrlX = lerp(0.22, 0.50) * w
        let spineCtrlY = lerp(0.48, 0.36) * h

        var spine = Path()
        spine.move(to: CGPoint(x: neckX, y: neckY))
        spine.addQuadCurve(
            to: CGPoint(x: hipX, y: hipY),
            control: CGPoint(x: spineCtrlX, y: spineCtrlY)
        )
        p.addPath(spine.strokedPath(StrokeStyle(lineWidth: bodyLw, lineCap: .round)))

        // Arms: from mid-spine area, resting on lap/knees
        let shoulderX = lerp(0.28, 0.50) * w
        let shoulderY = lerp(0.38, 0.26) * h
        let handX = lerp(0.22, 0.32) * w
        let handY = lerp(0.56, 0.52) * h

        var arm = Path()
        arm.move(to: CGPoint(x: shoulderX, y: shoulderY))
        arm.addQuadCurve(
            to: CGPoint(x: handX, y: handY),
            control: CGPoint(x: lerp(0.20, 0.34) * w, y: lerp(0.50, 0.42) * h)
        )
        p.addPath(arm.strokedPath(StrokeStyle(lineWidth: 0.05 * w, lineCap: .round)))

        // Upper leg: hip to knee (horizontal on seat)
        let kneeX: CGFloat = 0.28 * w
        let kneeY: CGFloat = 0.66 * h

        var upperLeg = Path()
        upperLeg.move(to: CGPoint(x: hipX, y: hipY))
        upperLeg.addLine(to: CGPoint(x: kneeX, y: kneeY))
        p.addPath(upperLeg.strokedPath(StrokeStyle(lineWidth: bodyLw, lineCap: .round)))

        // Lower leg: knee down to floor
        let footX: CGFloat = 0.26 * w
        let footY: CGFloat = 0.88 * h

        var lowerLeg = Path()
        lowerLeg.move(to: CGPoint(x: kneeX, y: kneeY))
        lowerLeg.addLine(to: CGPoint(x: footX, y: footY))
        p.addPath(lowerLeg.strokedPath(StrokeStyle(lineWidth: 0.06 * w, lineCap: .round)))

        return p
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
