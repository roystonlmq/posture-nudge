import Foundation
import UserNotifications
import AppKit

enum ReminderType {
    case posture, blink, eyeBreak

    var title: String {
        switch self {
        case .posture:  "Posture Check"
        case .blink:    "Blink Reminder"
        case .eyeBreak: "20-20-20 Eye Break"
        }
    }

    var body: String {
        switch self {
        case .posture:  "Time to sit up straight and roll your shoulders back."
        case .blink:    "Remember to blink slowly a few times."
        case .eyeBreak: "Look at something 20 feet away for 20 seconds."
        }
    }
}

@MainActor
final class NotificationManager: ObservableObject {
    @Published var permissionGranted: Bool = false
    @Published var permissionDenied: Bool = false

    private let center = UNUserNotificationCenter.current()

    func requestPermissionIfNeeded() async {
        guard AppRuntimeContext.isRunningAsAppBundle else {
            print("[PostureNudge] Not running as .app bundle - notifications skipped")
            return
        }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                permissionGranted = granted
                permissionDenied = !granted
            } catch {
                print("[PostureNudge] Notification auth error: \(error)")
                permissionDenied = true
            }
        case .authorized, .provisional, .ephemeral:
            permissionGranted = true
            permissionDenied = false
        case .denied:
            permissionGranted = false
            permissionDenied = true
        @unknown default:
            break
        }
    }

    func refreshPermissionStatus() async {
        guard AppRuntimeContext.isRunningAsAppBundle else { return }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            permissionGranted = true
            permissionDenied = false
        case .denied:
            permissionGranted = false
            permissionDenied = true
        default:
            break
        }
    }

    func send(_ type: ReminderType) {
        guard AppRuntimeContext.isRunningAsAppBundle, permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error { print("[PostureNudge] Notification error: \(error)") }
        }
    }

    func openSystemSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for urlString in urls {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
