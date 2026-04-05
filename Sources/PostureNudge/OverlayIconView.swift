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

    private var iconName: String {
        switch type {
        case .posture:  "chevron.up"
        case .blink:    "eye"
        case .eyeBreak: "binoculars"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: circleSize, height: circleSize)

            Circle()
                .strokeBorder(Color(white: 0.15), lineWidth: 4)
                .frame(width: circleSize, height: circleSize)

            Image(systemName: iconName)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color(white: 0.15))
        }
        .frame(width: 200, height: 200)
        .contentShape(Circle())
        .onTapGesture { onDismiss() }
    }
}
