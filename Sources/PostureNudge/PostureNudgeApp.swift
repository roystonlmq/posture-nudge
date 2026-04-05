import SwiftUI
import AppKit

@main
struct PostureNudgeApp: App {
    private let settingsStore: SettingsStore
    private let notificationManager: NotificationManager
    private let overlayManager: OverlayManager
    private let meetingDetector: MeetingDetector
    private let scheduler: ReminderScheduler

    init() {
        let store = SettingsStore()
        let notifications = NotificationManager()
        let overlay = OverlayManager()
        let detector = MeetingDetector()
        let sched = ReminderScheduler(
            settingsStore: store,
            overlayManager: overlay,
            meetingDetector: detector
        )
        self.settingsStore = store
        self.notificationManager = notifications
        self.overlayManager = overlay
        self.meetingDetector = detector
        self.scheduler = sched

        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                settingsStore: settingsStore,
                scheduler: scheduler,
                notificationManager: notificationManager,
                overlayManager: overlayManager,
                meetingDetector: meetingDetector
            )
        } label: {
            MenuBarLabel(scheduler: scheduler, meetingDetector: meetingDetector)
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
