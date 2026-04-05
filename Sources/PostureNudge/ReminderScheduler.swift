import Foundation
import Combine

@MainActor
final class ReminderScheduler: ObservableObject {
    @Published var postureNextFire: Date?
    @Published var blinkNextFire: Date?
    @Published var eyeBreakNextFire: Date?

    private var postureTimer: Timer?
    private var blinkTimer: Timer?
    private var eyeBreakTimer: Timer?

    private let overlayManager: OverlayManager
    private var settingsCancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    nonisolated(unsafe) private var activityToken: NSObjectProtocol?

    init(settingsStore: SettingsStore, overlayManager: OverlayManager) {
        self.overlayManager = overlayManager

        // Prevent App Nap from coalescing timers
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .idleSystemSleepDisabled],
            reason: "PostureNudge reminder timers"
        )

        configureTimers(settings: settingsStore.settings)

        settingsCancellable = settingsStore.$settings
            .dropFirst()
            .sink { [weak self] newSettings in
                self?.debounceReconfigure(settings: newSettings)
            }
    }

    deinit {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }

    private func debounceReconfigure(settings: NudgeSettings) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            configureTimers(settings: settings)
        }
    }

    private func configureTimers(settings: NudgeSettings) {
        // Posture
        postureTimer?.invalidate()
        postureTimer = nil
        postureNextFire = nil
        if settings.postureEnabled {
            let interval = TimeInterval(settings.postureIntervalMinutes * 60)
            postureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.overlayManager.show(.posture)
                }
            }
            postureNextFire = Date().addingTimeInterval(interval)
        }

        // Blink
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkNextFire = nil
        if settings.blinkEnabled {
            let interval = TimeInterval(settings.blinkIntervalMinutes * 60)
            blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.overlayManager.show(.blink)
                }
            }
            blinkNextFire = Date().addingTimeInterval(interval)
        }

        // Eye break
        eyeBreakTimer?.invalidate()
        eyeBreakTimer = nil
        eyeBreakNextFire = nil
        if settings.eyeBreakEnabled {
            let interval = TimeInterval(settings.eyeBreakIntervalMinutes * 60)
            eyeBreakTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.overlayManager.show(.eyeBreak)
                }
            }
            eyeBreakNextFire = Date().addingTimeInterval(interval)
        }
    }
}
