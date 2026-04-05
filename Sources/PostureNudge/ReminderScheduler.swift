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
    private var previousSettings: NudgeSettings
    private var settingsCancellable: AnyCancellable?
    private var meetingCancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    nonisolated(unsafe) private var activityToken: NSObjectProtocol?

    // Saved remaining time for meeting pause/resume
    private var savedRemaining: (posture: TimeInterval?, blink: TimeInterval?, eyeBreak: TimeInterval?) = (nil, nil, nil)

    init(settingsStore: SettingsStore, overlayManager: any OverlayShowing, meetingDetector: MeetingDetector) {
        self.overlayManager = overlayManager
        self.meetingDetector = meetingDetector
        self.currentSettings = settingsStore.settings
        self.previousSettings = settingsStore.settings

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .idleSystemSleepDisabled],
            reason: "PostureNudge reminder timers"
        )

        configureAllTimers(settings: settingsStore.settings)
        updateMeetingDetection(enabled: settingsStore.settings.meetingDetectionEnabled)

        settingsCancellable = settingsStore.$settings
            .dropFirst()
            .sink { [weak self] newSettings in
                guard let self else { return }
                let old = self.currentSettings
                self.previousSettings = old
                self.currentSettings = newSettings
                self.updateMeetingDetection(enabled: newSettings.meetingDetectionEnabled)
                self.debounceReconfigure(old: old, new: newSettings)
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

        // Save remaining time for each active timer
        savedRemaining = (
            posture: remainingTime(for: postureNextFire),
            blink: remainingTime(for: blinkNextFire),
            eyeBreak: remainingTime(for: eyeBreakNextFire)
        )

        postureTimer?.invalidate(); postureTimer = nil
        blinkTimer?.invalidate(); blinkTimer = nil
        eyeBreakTimer?.invalidate(); eyeBreakTimer = nil
    }

    private func resumeTimers() {
        guard isPausedForMeeting else { return }
        isPausedForMeeting = false

        let s = currentSettings
        let saved = savedRemaining
        savedRemaining = (nil, nil, nil)

        // Resume each timer from its saved remaining time
        resumeTimer(
            timer: &postureTimer, nextFire: &postureNextFire,
            enabled: s.postureEnabled, intervalMinutes: s.postureIntervalMinutes,
            savedRemaining: saved.posture, type: .posture
        )
        resumeTimer(
            timer: &blinkTimer, nextFire: &blinkNextFire,
            enabled: s.blinkEnabled, intervalMinutes: s.blinkIntervalMinutes,
            savedRemaining: saved.blink, type: .blink
        )
        resumeTimer(
            timer: &eyeBreakTimer, nextFire: &eyeBreakNextFire,
            enabled: s.eyeBreakEnabled, intervalMinutes: s.eyeBreakIntervalMinutes,
            savedRemaining: saved.eyeBreak, type: .eyeBreak
        )
    }

    private func remainingTime(for nextFire: Date?) -> TimeInterval? {
        guard let next = nextFire else { return nil }
        return max(1, next.timeIntervalSinceNow)
    }

    private func resumeTimer(
        timer: inout Timer?, nextFire: inout Date?,
        enabled: Bool, intervalMinutes: Int, savedRemaining: TimeInterval?, type: ReminderType
    ) {
        timer?.invalidate()
        timer = nil
        nextFire = nil
        guard enabled, let remaining = savedRemaining else { return }

        let interval = TimeInterval(intervalMinutes * 60)
        nextFire = Date().addingTimeInterval(remaining)

        // First fire uses the saved remaining time, then repeats at full interval
        timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.overlayManager.show(type)
                // Now set up the repeating timer at full interval
                self.startRepeatingTimer(type: type, interval: interval)
            }
        }
    }

    // MARK: - Timer management

    private func debounceReconfigure(old: NudgeSettings, new: NudgeSettings) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            guard !self.isPausedForMeeting else { return }
            self.reconfigureChangedTimers(old: old, new: new)
        }
    }

    /// Only reconfigure timers whose settings actually changed
    private func reconfigureChangedTimers(old: NudgeSettings, new: NudgeSettings) {
        if old.postureEnabled != new.postureEnabled || old.postureIntervalMinutes != new.postureIntervalMinutes {
            configureTimer(
                timer: &postureTimer, nextFire: &postureNextFire,
                enabled: new.postureEnabled, intervalMinutes: new.postureIntervalMinutes,
                type: .posture
            )
        }
        if old.blinkEnabled != new.blinkEnabled || old.blinkIntervalMinutes != new.blinkIntervalMinutes {
            configureTimer(
                timer: &blinkTimer, nextFire: &blinkNextFire,
                enabled: new.blinkEnabled, intervalMinutes: new.blinkIntervalMinutes,
                type: .blink
            )
        }
        if old.eyeBreakEnabled != new.eyeBreakEnabled || old.eyeBreakIntervalMinutes != new.eyeBreakIntervalMinutes {
            configureTimer(
                timer: &eyeBreakTimer, nextFire: &eyeBreakNextFire,
                enabled: new.eyeBreakEnabled, intervalMinutes: new.eyeBreakIntervalMinutes,
                type: .eyeBreak
            )
        }
    }

    /// Configure all timers fresh (used on init)
    private func configureAllTimers(settings: NudgeSettings) {
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

    private func startRepeatingTimer(type: ReminderType, interval: TimeInterval) {
        setNextFire(for: type, interval: interval)

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.setNextFire(for: type, interval: interval)
                self.overlayManager.show(type)
            }
        }

        switch type {
        case .posture:  postureTimer = timer
        case .blink:    blinkTimer = timer
        case .eyeBreak: eyeBreakTimer = timer
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
