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

// MARK: - Posture: person in chair, slouched -> upright

private struct PostureIcon: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        PostureFigure(progress: progress)
            .fill(Color(white: 0.15))
            .frame(width: 70, height: 70)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                    progress = 1.0
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

        // === CHAIR (constant) ===

        // Chair back
        p.addRoundedRect(
            in: CGRect(x: 0.62 * w, y: 0.18 * h, width: 0.12 * w, height: 0.50 * h),
            cornerSize: CGSize(width: 4, height: 4)
        )
        // Seat
        p.addRoundedRect(
            in: CGRect(x: 0.10 * w, y: 0.60 * h, width: 0.64 * w, height: 0.10 * h),
            cornerSize: CGSize(width: 3, height: 3)
        )
        // Armrest
        p.addRoundedRect(
            in: CGRect(x: 0.06 * w, y: 0.42 * h, width: 0.10 * w, height: 0.22 * h),
            cornerSize: CGSize(width: 3, height: 3)
        )
        // Front leg
        p.addRoundedRect(
            in: CGRect(x: 0.12 * w, y: 0.70 * h, width: 0.06 * w, height: 0.20 * h),
            cornerSize: CGSize(width: 2, height: 2)
        )
        // Back leg
        p.addRoundedRect(
            in: CGRect(x: 0.66 * w, y: 0.70 * h, width: 0.06 * w, height: 0.20 * h),
            cornerSize: CGSize(width: 2, height: 2)
        )

        // === PERSON ===

        // Head: moves from low-left (slouched) to high-center (upright)
        let headR: CGFloat = 0.10 * w
        let headX = lerp(0.22, 0.50) * w
        let headY = lerp(0.30, 0.05) * h
        p.addEllipse(in: CGRect(
            x: headX - headR, y: headY - headR,
            width: headR * 2, height: headR * 2
        ))

        // Torso: curved line from neck to hip
        let neckX = lerp(0.26, 0.50) * w
        let neckY = headY + headR + 1
        let hipX: CGFloat = 0.48 * w
        let hipY: CGFloat = 0.58 * h
        let spineCtrlX = lerp(0.24, 0.49) * w
        let spineCtrlY = lerp(0.48, 0.38) * h

        var torso = Path()
        torso.move(to: CGPoint(x: neckX, y: neckY))
        torso.addQuadCurve(
            to: CGPoint(x: hipX, y: hipY),
            control: CGPoint(x: spineCtrlX, y: spineCtrlY)
        )
        p.addPath(torso.strokedPath(StrokeStyle(
            lineWidth: 0.08 * w, lineCap: .round
        )))

        // Arm: from shoulder area toward armrest or dangling
        let shoulderX = lerp(0.24, 0.48) * w
        let shoulderY = lerp(0.40, 0.24) * h
        let handX = lerp(0.14, 0.16) * w
        let handY = lerp(0.54, 0.48) * h
        let elbowX = lerp(0.16, 0.26) * w
        let elbowY = lerp(0.50, 0.40) * h

        var arm = Path()
        arm.move(to: CGPoint(x: shoulderX, y: shoulderY))
        arm.addQuadCurve(
            to: CGPoint(x: handX, y: handY),
            control: CGPoint(x: elbowX, y: elbowY)
        )
        p.addPath(arm.strokedPath(StrokeStyle(
            lineWidth: 0.05 * w, lineCap: .round
        )))

        // Upper leg: hip to knee (on the seat)
        let kneeX: CGFloat = 0.24 * w
        let kneeY: CGFloat = 0.68 * h

        var upperLeg = Path()
        upperLeg.move(to: CGPoint(x: hipX, y: hipY))
        upperLeg.addLine(to: CGPoint(x: kneeX, y: kneeY))
        p.addPath(upperLeg.strokedPath(StrokeStyle(
            lineWidth: 0.07 * w, lineCap: .round
        )))

        // Lower leg: knee to foot
        let footX: CGFloat = 0.22 * w
        let footY: CGFloat = 0.88 * h

        var lowerLeg = Path()
        lowerLeg.move(to: CGPoint(x: kneeX, y: kneeY))
        lowerLeg.addLine(to: CGPoint(x: footX, y: footY))
        p.addPath(lowerLeg.strokedPath(StrokeStyle(
            lineWidth: 0.06 * w, lineCap: .round
        )))

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
