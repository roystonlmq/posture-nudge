import SwiftUI
import AppKit

@main
struct PostureNudgeApp: App {
    private let settingsStore: SettingsStore
    private let notificationManager: NotificationManager
    private let scheduler: ReminderScheduler

    init() {
        let store = SettingsStore()
        let notifications = NotificationManager()
        let sched = ReminderScheduler(settingsStore: store, notificationManager: notifications)
        self.settingsStore = store
        self.notificationManager = notifications
        self.scheduler = sched

        // Disable automatic window tabbing
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                settingsStore: settingsStore,
                scheduler: scheduler,
                notificationManager: notificationManager
            )
            .task {
                await notificationManager.requestPermissionIfNeeded()
            }
        } label: {
            Image(systemName: "figure.stand")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settingsStore: settingsStore,
                notificationManager: notificationManager
            )
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { await notificationManager.refreshPermissionStatus() }
            }
        }
    }
}
