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
            .onAppear {
                // Switch from accessory (menu bar only) to regular so the
                // settings window becomes key and controls aren't greyed out.
                // The short delay lets the window system process the policy
                // change before we attempt activation.
                NSApp.setActivationPolicy(.regular)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApp.activate()
                    if let settingsWindow = NSApp.windows.first(where: {
                        $0.isVisible && $0.canBecomeKey && !($0 is NSPanel)
                    }) {
                        settingsWindow.makeKeyAndOrderFront(nil)
                    }
                }
            }
            .onDisappear {
                // Return to menu bar only mode when settings closes
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
