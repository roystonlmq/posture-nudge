import SwiftUI
import AppKit

@main
struct PostureNudgeApp: App {
    private let settingsStore: SettingsStore
    private let notificationManager: NotificationManager
    private let overlayManager: OverlayManager
    private let meetingDetector: MeetingDetector
    private let scheduler: ReminderScheduler

    /// Shared state so MenuBarView can open the settings window.
    static var shared: PostureNudgeApp?
    private static var settingsWindow: NSWindow?
    private static var closeObserver: NSObjectProtocol?

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
        PostureNudgeApp.shared = self
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
    }

    /// Opens the settings window, creating it if needed.
    func showSettings() {
        if let existing = Self.settingsWindow, existing.isVisible {
            NSApp.setActivationPolicy(.regular)
            existing.orderFrontRegardless()
            existing.makeKey()
            NSApp.activate()
            return
        }

        let view = SettingsView(
            settingsStore: settingsStore,
            notificationManager: notificationManager
        )
        let scrollView = NSHostingController(rootView:
            ScrollView {
                view
            }
            .frame(width: 420, height: 500)
        )
        let window = NSWindow(contentViewController: scrollView)
        window.title = "PostureNudge Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 500))
        window.center()

        Self.settingsWindow = window

        // Clean up when the window actually closes
        if let old = Self.closeObserver {
            NotificationCenter.default.removeObserver(old)
        }
        Self.closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window, queue: .main
        ) { _ in
            NSApp.setActivationPolicy(.accessory)
        }

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
