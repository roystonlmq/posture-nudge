import SwiftUI
import AppKit

@main
struct PostureNudgeApp: App {
    private let settingsStore: SettingsStore
    private let notificationManager: NotificationManager
    private let overlayManager: OverlayManager
    private let scheduler: ReminderScheduler

    init() {
        let store = SettingsStore()
        let notifications = NotificationManager()
        let overlay = OverlayManager()
        let sched = ReminderScheduler(settingsStore: store, overlayManager: overlay)
        self.settingsStore = store
        self.notificationManager = notifications
        self.overlayManager = overlay
        self.scheduler = sched

        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                settingsStore: settingsStore,
                scheduler: scheduler,
                notificationManager: notificationManager
            )
        } label: {
            Image(systemName: "figure.stand")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settingsStore: settingsStore,
                notificationManager: notificationManager
            )
        }
    }
}
