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

// MARK: - Posture: figure straightens up

private struct PostureIcon: View {
    @State private var isUpright = false

    var body: some View {
        Image(systemName: "figure.stand")
            .font(.system(size: 48, weight: .medium))
            .foregroundStyle(Color(white: 0.15))
            .rotationEffect(.degrees(isUpright ? 0 : 15), anchor: .bottom)
            .offset(y: isUpright ? -2 : 4)
            .onAppear {
                // Start slouched, then straighten
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    isUpright = true
                }
            }
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
        // First blink at 0.4s
        withAnimation(.easeIn(duration: 0.12).delay(0.4)) {
            blinkPhase = 0.05
        }
        withAnimation(.easeOut(duration: 0.15).delay(0.52)) {
            blinkPhase = 1
        }
        // Second blink at 1.2s
        withAnimation(.easeIn(duration: 0.12).delay(1.2)) {
            blinkPhase = 0.05
        }
        withAnimation(.easeOut(duration: 0.15).delay(1.32)) {
            blinkPhase = 1
        }
        // Third blink at 2.0s
        withAnimation(.easeIn(duration: 0.12).delay(2.0)) {
            blinkPhase = 0.05
        }
        withAnimation(.easeOut(duration: 0.15).delay(2.12)) {
            blinkPhase = 1
        }
    }
}
