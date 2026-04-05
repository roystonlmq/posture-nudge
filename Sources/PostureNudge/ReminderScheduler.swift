import Foundation
import Combine

@MainActor
final class ReminderScheduler: ObservableObject {
    @Published var postureNextFire: Date?
    @Published var blinkNextFire: Date?
    @Published var eyeBreakNextFire: Date?
    @Published private(set) var isPausedForMeeting: Bool = false

    private var postureTimer: Timer?
    private var blinkTimer: Timer?
    private var eyeBreakTimer: Timer?

    private let overlayManager: any OverlayShowing
    private let meetingDetector: MeetingDetector
    private var currentSettings: NudgeSettings
    private var settingsCancellable: AnyCancellable?
    private var meetingCancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    nonisolated(unsafe) private var activityToken: NSObjectProtocol?

    init(settingsStore: SettingsStore, overlayManager: any OverlayShowing, meetingDetector: MeetingDetector) {
        self.overlayManager = overlayManager
        self.meetingDetector = meetingDetector
        self.currentSettings = settingsStore.settings

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .idleSystemSleepDisabled],
            reason: "PostureNudge reminder timers"
        )

        configureTimers(settings: settingsStore.settings)
        updateMeetingDetection(enabled: settingsStore.settings.meetingDetectionEnabled)

        settingsCancellable = settingsStore.$settings
            .dropFirst()
            .sink { [weak self] newSettings in
                self?.currentSettings = newSettings
                self?.updateMeetingDetection(enabled: newSettings.meetingDetectionEnabled)
                self?.debounceReconfigure(settings: newSettings)
            }

        meetingCancellable = meetingDetector.$isMeetingActive
            .removeDuplicates()
            .sink { [weak self] inMeeting in
                if inMeeting {
                    self?.pauseTimers()
                } else {
                    self?.resumeTimers()
                }
            }
    }

    deinit {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }

    // MARK: - Meeting detection

    private func updateMeetingDetection(enabled: Bool) {
        if enabled {
            meetingDetector.start()
        } else {
            meetingDetector.stop()
            if isPausedForMeeting {
                resumeTimers()
            }
        }
    }

    private func pauseTimers() {
        guard !isPausedForMeeting else { return }
        isPausedForMeeting = true
        postureTimer?.invalidate(); postureTimer = nil
        blinkTimer?.invalidate(); blinkTimer = nil
        eyeBreakTimer?.invalidate(); eyeBreakTimer = nil
        postureNextFire = nil
        blinkNextFire = nil
        eyeBreakNextFire = nil
    }

    private func resumeTimers() {
        guard isPausedForMeeting else { return }
        isPausedForMeeting = false
        configureTimers(settings: currentSettings)
    }

    // MARK: - Timer management

    private func debounceReconfigure(settings: NudgeSettings) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            guard !self.isPausedForMeeting else { return }
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
