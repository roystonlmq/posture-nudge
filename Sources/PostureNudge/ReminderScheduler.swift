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

    private let overlayManager: any OverlayShowing
    private var settingsCancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    nonisolated(unsafe) private var activityToken: NSObjectProtocol?

    init(settingsStore: SettingsStore, overlayManager: any OverlayShowing) {
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
        configureTimer(
            timer: &postureTimer, nextFire: &postureNextFire,
            enabled: settings.postureEnabled, intervalMinutes: settings.postureIntervalMinutes,
            type: .posture
        )
        configureTimer(
            timer: &blinkTimer, nextFire: &blinkNextFire,
            enabled: settings.blinkEnabled, intervalMinutes: settings.blinkIntervalMinutes,
            type: .blink
        )
        configureTimer(
            timer: &eyeBreakTimer, nextFire: &eyeBreakNextFire,
            enabled: settings.eyeBreakEnabled, intervalMinutes: settings.eyeBreakIntervalMinutes,
            type: .eyeBreak
        )
    }

    private func configureTimer(
        timer: inout Timer?, nextFire: inout Date?,
        enabled: Bool, intervalMinutes: Int, type: ReminderType
    ) {
        timer?.invalidate()
        timer = nil
        nextFire = nil
        guard enabled else { return }

        let interval = TimeInterval(intervalMinutes * 60)
        nextFire = Date().addingTimeInterval(interval)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Set next fire BEFORE showing overlay so the menu bar
                // never briefly counts up from a past date
                self.setNextFire(for: type, interval: interval)
                self.overlayManager.show(type)
            }
        }
    }

    private func setNextFire(for type: ReminderType, interval: TimeInterval) {
        let next = Date().addingTimeInterval(interval)
        switch type {
        case .posture:  postureNextFire = next
        case .blink:    blinkNextFire = next
        case .eyeBreak: eyeBreakNextFire = next
        }
    }
}
