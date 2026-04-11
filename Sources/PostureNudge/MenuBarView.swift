import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var scheduler: ReminderScheduler
    @ObservedObject var notificationManager: NotificationManager
    var overlayManager: OverlayManager
    @ObservedObject var meetingDetector: MeetingDetector
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "figure.stand")
                    .foregroundStyle(Color.accentColor)
                Text("PostureNudge")
                    .font(.headline)
                Spacer()
            }

            if scheduler.isPausedForMeeting {
                HStack(spacing: 6) {
                    if meetingDetector.isScreenLocked {
                        Image(systemName: "lock.display")
                            .foregroundStyle(.orange)
                        Text("Paused - screen locked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if meetingDetector.isMeetingActive {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.orange)
                        Text("Paused - in meeting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if meetingDetector.isUserIdle {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.orange)
                        Text("Paused - idle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if notificationManager.permissionDenied {
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Text("Notifications blocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Fix") {
                        notificationManager.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            Divider()

            // Reminders
            ReminderRow(
                icon: "figure.stand",
                label: "Posture",
                enabled: $settingsStore.settings.postureEnabled,
                nextFire: scheduler.postureNextFire
            )
            ReminderRow(
                icon: "eye",
                label: "Blink",
                enabled: $settingsStore.settings.blinkEnabled,
                nextFire: scheduler.blinkNextFire
            )
            ReminderRow(
                icon: "binoculars",
                label: "Eye Break",
                enabled: $settingsStore.settings.eyeBreakEnabled,
                nextFire: scheduler.eyeBreakNextFire
            )

            #if DEBUG
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Debug")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 8) {
                    Button("Posture") { overlayManager.show(.posture) }
                    Button("Blink") { overlayManager.show(.blink) }
                    Button("Eye Break") { overlayManager.show(.eyeBreak) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                HStack(spacing: 4) {
                    Circle()
                        .fill(meetingDetector.cameraInUse ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text("Cam")
                        .font(.caption2)
                    Circle()
                        .fill(meetingDetector.microphoneInUse ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text("Mic")
                        .font(.caption2)
                    Circle()
                        .fill(meetingDetector.isUserIdle ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text("Idle")
                        .font(.caption2)
                    Circle()
                        .fill(meetingDetector.isScreenLocked ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Text("Lock")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            #endif

            Divider()

            HStack {
                Button("Settings...") {
                    PostureNudgeApp.shared?.showSettings()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 4) {
                Text("by")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Link("@roystonlmq", destination: URL(string: "https://github.com/roystonlmq/posture-nudge")!)
                    .font(.caption2)
                Spacer()
                Text("Inspired by")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Link("LookAway", destination: URL(string: "https://lookaway.com")!)
                    .font(.caption2)
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}

private struct ReminderRow: View {
    let icon: String
    let label: String
    @Binding var enabled: Bool
    let nextFire: Date?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(enabled ? .primary : .tertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(enabled ? .primary : .secondary)
                if enabled, let next = nextFire {
                    Text("Next: \(next, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Off")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $enabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}
