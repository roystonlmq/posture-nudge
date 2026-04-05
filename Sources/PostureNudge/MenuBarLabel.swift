import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var scheduler: ReminderScheduler
    @ObservedObject var meetingDetector: MeetingDetector

    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "figure.stand")

            if scheduler.isPausedForMeeting {
                if meetingDetector.isMeetingActive {
                    Text("meeting")
                        .font(.caption2)
                } else {
                    Text("idle")
                        .font(.caption2)
                }
            } else if let label = nextReminderLabel {
                Text(label)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var nextReminderLabel: String? {
        // Find the soonest next fire across all reminders
        let fires = [
            scheduler.postureNextFire,
            scheduler.blinkNextFire,
            scheduler.eyeBreakNextFire
        ].compactMap { $0 }

        guard let soonest = fires.min() else { return nil }

        let remaining = Int(max(0, soonest.timeIntervalSince(now)))
        let minutes = remaining / 60
        let seconds = remaining % 60

        if minutes >= 60 {
            return "\(minutes / 60)h\(minutes % 60)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}
