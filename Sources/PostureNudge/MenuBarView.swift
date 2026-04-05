import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var scheduler: ReminderScheduler
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.openSettings) private var openSettings

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

            Divider()

            HStack {
                Button("Settings...") {
                    openSettings()
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
