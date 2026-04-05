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

            Section("Meeting Detection") {
                Toggle("Pause during meetings", isOn: $settingsStore.settings.meetingDetectionEnabled)
                Text("Automatically pauses all reminders when your camera or microphone is in use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Idle Detection") {
                Toggle("Pause when idle", isOn: $settingsStore.settings.idleDetectionEnabled)
                if settingsStore.settings.idleDetectionEnabled {
                    IntervalField(
                        label: "Idle after",
                        value: $settingsStore.settings.idleThresholdMinutes
                    )
                }
                Text("Pauses reminders when you step away from your computer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: $text)
                .frame(width: 50)
                .multilineTextAlignment(.trailing)
                .onAppear { text = "\(value)" }
                .onChange(of: text) { commitText() }
                .onChange(of: value) { text = "\(value)" }
            Text("min")
                .foregroundStyle(.secondary)
            Stepper("", value: $value, in: 1...120, step: 1)
                .labelsHidden()
        }
    }

    private func commitText() {
        guard let parsed = Int(text), parsed >= 1, parsed <= 120 else { return }
        if parsed != value {
            value = parsed
        }
    }
}
