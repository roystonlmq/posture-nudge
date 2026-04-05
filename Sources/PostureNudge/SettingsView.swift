import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var notificationManager: NotificationManager

    var body: some View {
        Form {
            if notificationManager.permissionDenied {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Blocked")
                                .font(.callout)
                                .fontWeight(.medium)
                            Text("PostureNudge needs notification permission to send reminders.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open System Settings") {
                            notificationManager.openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Posture") {
                Toggle("Enable posture reminders", isOn: $settingsStore.settings.postureEnabled)
                if settingsStore.settings.postureEnabled {
                    IntervalField(
                        label: "Remind every",
                        value: $settingsStore.settings.postureIntervalMinutes
                    )
                }
            }

            Section("Blink") {
                Toggle("Enable blink reminders", isOn: $settingsStore.settings.blinkEnabled)
                if settingsStore.settings.blinkEnabled {
                    IntervalField(
                        label: "Remind every",
                        value: $settingsStore.settings.blinkIntervalMinutes
                    )
                }
            }

            Section("20-20-20 Eye Break") {
                Toggle("Enable eye break reminders", isOn: $settingsStore.settings.eyeBreakEnabled)
                if settingsStore.settings.eyeBreakEnabled {
                    IntervalField(
                        label: "Remind every",
                        value: $settingsStore.settings.eyeBreakIntervalMinutes
                    )
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.vertical, 8)
    }
}

private struct IntervalField: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: $value, format: .number)
                .frame(width: 50)
                .multilineTextAlignment(.trailing)
                .onSubmit { clampValue() }
                .onChange(of: value) { clampValue() }
            Text("min")
                .foregroundStyle(.secondary)
        }
    }

    private func clampValue() {
        value = max(1, min(120, value))
    }
}
