import SwiftUI

struct BreakOverlayView: View {
    let remainingSeconds: Int
    let onSkip: () -> Void

    private var timerText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: 0.47, saturation: 0.80, brightness: 0.75),
                Color(hue: 0.58, saturation: 0.85, brightness: 0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            // Full-screen dimmed background
            Color.black.opacity(0.75)

            VStack(spacing: 28) {
                // Icon
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 100, height: 100)

                    Circle()
                        .strokeBorder(Color(white: 0.15), lineWidth: 4)
                        .frame(width: 100, height: 100)

                    Image(systemName: "binoculars")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(Color(white: 0.15))
                }

                // Instruction
                Text("Look 20 feet away")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)

                // Countdown
                Text(timerText)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                // Skip button
                Button(action: onSkip) {
                    Text("Skip Break")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .ignoresSafeArea()
    }
}
